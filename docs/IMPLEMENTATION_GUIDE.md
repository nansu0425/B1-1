# 시스템 관제 자동화 — 구현 가이드 (B1-1)

이 문서는 [MISSION.md](MISSION.md) 의 필수 요구사항(§4.1 ~ §4.5)을 처음부터 끝까지 수행하기 위한 실행 가이드다. 각 절은 **실행 명령 → 검증 명령 → 기대 출력** 순으로 구성되어 있으며, 명령은 그대로 복사·실행할 수 있다.

> 보너스 과제(report.sh, 로그 보존 정책)는 본 가이드 범위에 포함되지 않는다.

---

## 0. 사전 준비

### 0.1 가정하는 환경

| 항목 | 값 |
| --- | --- |
| OS | Ubuntu 22.04 LTS (x86_64) — VM 권장 |
| 셸 | `bash` |
| 권한 | `sudo` 가능한 사용자로 로그인되어 있음 |
| 저장소 위치 | `~/Codyssey/B1-1` (Windows 호스트의 저장소를 VM 안으로 동기화 또는 git clone) |
| 제공 바이너리 | `agent-app/agent-app-linux-x86` (ELF 64-bit) |

### 0.2 작업 순서 한눈에 보기

```
[0] 패키지 설치
  └─[1] SSH 보안 (포트 20022, root 차단)
     └─[2] UFW 방화벽 (20022/tcp, 15034/tcp 만 허용)
        └─[3] 그룹/사용자/디렉토리/ACL
           └─[4] 환경 변수 + 키 파일
              └─[5] 앱 배포 및 실행 검증
                 └─[6] monitor.sh 배포 및 단독 실행 검증
                    └─[7] cron 등록 (매분 실행)
                       └─[8] 최종 체크리스트 검증
```

⚠️ **반드시 순서대로 진행**해야 한다. 특히 §2의 UFW는 §1에서 SSH 포트를 변경한 뒤에 활성화해야 락아웃을 피할 수 있다.

### 0.3 필요 패키지 설치

```bash
sudo apt update
sudo apt install -y openssh-server ufw cron acl iproute2 procps coreutils
sudo systemctl enable --now ssh
sudo systemctl enable --now cron
```

### 0.4 제공 바이너리 위치 확인

```bash
file ~/Codyssey/B1-1/agent-app/agent-app-linux-x86
# 기대: ELF 64-bit LSB executable, x86-64 ...
```

---

## 1. SSH 보안 설정  ☑ 체크리스트 ①

### 1.1 설정 변경

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d)

# 포트와 root 차단을 멱등하게 적용
sudo sed -i \
    -e 's/^#\?Port .*/Port 20022/' \
    -e 's/^#\?PermitRootLogin .*/PermitRootLogin no/' \
    /etc/ssh/sshd_config

# Port 행이 없었던 경우 추가 보장
grep -q '^Port 20022' /etc/ssh/sshd_config || \
    echo 'Port 20022' | sudo tee -a /etc/ssh/sshd_config

# Ubuntu 22.04의 socket-activated SSH 와 충돌하지 않도록 socket override 제거
sudo systemctl disable --now ssh.socket 2>/dev/null || true
```

### 1.2 sshd 재시작

```bash
sudo systemctl restart ssh
sudo systemctl status ssh --no-pager
```

### 1.3 검증

```bash
# 설정 값 확인
sudo sshd -T | grep -Ei '^port|^permitrootlogin'
# 기대:
#   port 20022
#   permitrootlogin no

# 실제 LISTEN 포트 확인
ss -tulnp | grep -E 'sshd|:20022'
# 기대 (예): LISTEN 0 128 0.0.0.0:20022 ... users:(("sshd",pid=...,fd=3))
```

> 원격에서 들어와 있다면 **이 시점에 새 세션을 `ssh -p 20022` 로 한 번 더 열어** 접속 가능 여부를 확인하라. 그 다음에 §2로 넘어간다.

---

## 2. UFW 방화벽 설정  ☑ 체크리스트 ②

### 2.1 ⚠️ 락아웃 방지 — enable 전에 SSH 포트 먼저 허용

```bash
# 새 SSH 포트와 앱 포트를 먼저 허용
sudo ufw allow 20022/tcp comment 'SSH (custom)'
sudo ufw allow 15034/tcp comment 'agent-app'

# 기본 정책: 인바운드 deny, 아웃바운드 allow
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 활성화
sudo ufw --force enable
```

### 2.2 검증

```bash
sudo ufw status verbose
```

**기대 출력 (요지):**
```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

To                         Action      From
--                         ------      ----
20022/tcp                  ALLOW IN    Anywhere
15034/tcp                  ALLOW IN    Anywhere
20022/tcp (v6)             ALLOW IN    Anywhere (v6)
15034/tcp (v6)             ALLOW IN    Anywhere (v6)
```

`Status: active` 와 위 4개 규칙(20022, 15034 각각 v4/v6) 외에 다른 인바운드 ALLOW 가 없어야 한다.

---

## 3. 계정 / 그룹 / 디렉토리 / ACL  ☑ 체크리스트 ③ ④

### 3.1 그룹 생성

```bash
sudo groupadd -f agent-common
sudo groupadd -f agent-core
```

### 3.2 사용자 생성

```bash
# agent-admin: 운영/관리, cron 실행자 (agent-common + agent-core)
sudo useradd -m -s /bin/bash -G agent-common,agent-core agent-admin

# agent-dev: monitor.sh 작성자 (agent-common + agent-core)
sudo useradd -m -s /bin/bash -G agent-common,agent-core agent-dev

# agent-test: QA (agent-common 만)
sudo useradd -m -s /bin/bash -G agent-common agent-test

# (옵션) 비밀번호 설정 — 필요 시
# sudo passwd agent-admin && sudo passwd agent-dev && sudo passwd agent-test
```

### 3.3 디렉토리 생성

```bash
# AGENT_HOME 및 하위 디렉토리
sudo -u agent-admin mkdir -p /home/agent-admin/agent-app/{bin,upload_files,api_keys}

# 로그 디렉토리 (시스템 위치)
sudo mkdir -p /var/log/agent-app
```

### 3.4 권한 설정 (소유자 · 그룹 · 모드 · ACL)

```bash
# AGENT_HOME 자체는 agent-admin 소유 그대로 두되, 하위 디렉토리에 정책 적용

# (a) upload_files : agent-common 공유 R/W
sudo chown agent-admin:agent-common /home/agent-admin/agent-app/upload_files
sudo chmod 2770 /home/agent-admin/agent-app/upload_files
sudo setfacl -d -m g:agent-common:rwx /home/agent-admin/agent-app/upload_files

# (b) api_keys : agent-core 만 R/W
sudo chown agent-admin:agent-core /home/agent-admin/agent-app/api_keys
sudo chmod 2770 /home/agent-admin/agent-app/api_keys
sudo setfacl -d -m g:agent-core:rwx /home/agent-admin/agent-app/api_keys

# (c) /var/log/agent-app : agent-core 만 R/W (monitor.sh 가 쓰는 위치)
sudo chown root:agent-core /var/log/agent-app
sudo chmod 2770 /var/log/agent-app
sudo setfacl -d -m g:agent-core:rwx /var/log/agent-app

# bin 디렉토리 : agent-core 그룹이 실행 가능해야 함
sudo chown agent-admin:agent-core /home/agent-admin/agent-app/bin
sudo chmod 2750 /home/agent-admin/agent-app/bin
```

### 3.5 검증

```bash
# 계정/그룹 소속
id agent-admin
# 기대(예): uid=1001(agent-admin) gid=1001(agent-admin) groups=1001(agent-admin),1002(agent-common),1003(agent-core)
id agent-dev
# 기대: groups에 agent-common, agent-core 모두 포함
id agent-test
# 기대: groups에 agent-common 포함, agent-core 비포함

# 디렉토리 소유/모드
ls -ld /home/agent-admin/agent-app /home/agent-admin/agent-app/* /var/log/agent-app
# 기대(요지):
#   drwxr-xr-x  agent-admin agent-admin   .../agent-app
#   drwxr-s---  agent-admin agent-common  .../upload_files     (2770 + setgid 's')
#   drwxr-s---  agent-admin agent-core    .../api_keys
#   drwxr-s---  agent-admin agent-core    .../bin
#   drwxrws---  root        agent-core    /var/log/agent-app

# ACL 확인
getfacl /home/agent-admin/agent-app/upload_files
getfacl /home/agent-admin/agent-app/api_keys
getfacl /var/log/agent-app
# 기대: default:group:agent-common:rwx (또는 agent-core:rwx) 라인 포함
```

---

## 4. 환경 변수 및 키 파일

### 4.1 시스템 전역 환경 변수

```bash
sudo tee /etc/profile.d/agent-app.sh >/dev/null <<'EOF'
# agent-app 실행 환경 변수
export AGENT_HOME="/home/agent-admin/agent-app"
export AGENT_PORT="15034"
export AGENT_UPLOAD_DIR="$AGENT_HOME/upload_files"
export AGENT_KEY_PATH="$AGENT_HOME/api_keys/t_secret.key"
export AGENT_LOG_DIR="/var/log/agent-app"
EOF
sudo chmod 644 /etc/profile.d/agent-app.sh
```

### 4.2 키 파일 생성

```bash
sudo -u agent-admin bash -lc '
    printf "agent_api_key_test\n" > "$AGENT_KEY_PATH"
    chmod 640 "$AGENT_KEY_PATH"
'
# 그룹 소유(agent-core) 는 api_keys 디렉토리의 setgid 로 자동 상속됨
ls -l /home/agent-admin/agent-app/api_keys/t_secret.key
# 기대: -rw-r----- 1 agent-admin agent-core ... t_secret.key
```

### 4.3 검증

```bash
sudo -iu agent-admin env | grep '^AGENT_'
# 기대:
#   AGENT_HOME=/home/agent-admin/agent-app
#   AGENT_PORT=15034
#   AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files
#   AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys/t_secret.key
#   AGENT_LOG_DIR=/var/log/agent-app

sudo -u agent-admin cat /home/agent-admin/agent-app/api_keys/t_secret.key
# 기대: agent_api_key_test
```

---

## 5. 애플리케이션 배포 및 실행  ☑ 체크리스트 ⑤

### 5.1 바이너리 배치

`monitor.sh` 가 `pgrep -f 'agent_app'` 로 프로세스를 식별하므로, 식별자 일관성을 위해 바이너리를 **`agent_app`** 로 rename 해 배치한다.

```bash
# 저장소 → AGENT_HOME 으로 복사 + rename
sudo install -o agent-admin -g agent-core -m 0750 \
    ~/Codyssey/B1-1/agent-app/agent-app-linux-x86 \
    /home/agent-admin/agent-app/agent_app

ls -l /home/agent-admin/agent-app/agent_app
# 기대: -rwxr-x--- 1 agent-admin agent-core ... agent_app
```

### 5.2 앱 실행 (포어그라운드, 일반 계정)

별도 터미널을 열어 실행 상태를 유지한다.

```bash
# 새 터미널 — agent-admin 으로 앱 실행
sudo -iu agent-admin -- bash -lc '"$AGENT_HOME/agent_app"'
```

### 5.3 Boot Sequence 확인  ☑ 체크리스트 ⑤

콘솔에 다음과 같이 출력되어야 한다(문구는 다를 수 있다).

```text
> Starting Agent Boot Sequence...
[1/5] Checking User Account               [OK]
[2/5] Verifying Environment Variables     [OK]
[3/5] Checking Required Files             [OK]
[4/5] Checking Port Availability          [OK]
[5/5] Verifying Log Permission            [OK]
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
```

5단계 모두 `[OK]` 이고 마지막에 **Agent READY** 가 출력되어야 한다. 어느 단계든 실패하면 §3, §4 의 권한·환경 변수를 다시 확인한다 (부록 A 참조).

### 5.4 포트 LISTEN 확인

```bash
# 다른 터미널에서
ss -tulnp | grep ':15034'
# 기대: LISTEN 0 ... 0.0.0.0:15034 ... users:(("agent_app",pid=...,fd=...))
```

> 다음 §6, §7 에서 monitor.sh 와 cron 검증을 진행하려면 **앱 프로세스가 계속 실행 중**이어야 한다. 종료는 모든 검증이 끝난 뒤 `Ctrl+C` 로 한다.

---

## 6. `monitor.sh` 배포 및 검증  ☑ 체크리스트 ⑥

저장소의 `scripts/monitor.sh` 가 미션 §4.4 의 모든 요구를 충족하는 구현이다. 이를 `$AGENT_HOME/bin/monitor.sh` 로 배포한다.

### 6.1 배포

```bash
sudo install -o agent-dev -g agent-core -m 0750 \
    ~/Codyssey/B1-1/scripts/monitor.sh \
    /home/agent-admin/agent-app/bin/monitor.sh

ls -l /home/agent-admin/agent-app/bin/monitor.sh
# 기대: -rwxr-x--- 1 agent-dev agent-core ... monitor.sh
```

### 6.2 스크립트 사양 (참고)

`scripts/monitor.sh` 는 다음을 수행한다:

| 영역 | 동작 |
| --- | --- |
| 환경 변수 | `/etc/profile.d/agent-app.sh` 를 source (cron 환경 대응) |
| Health: 프로세스 | `pgrep -f 'agent_app'`, 없으면 `[FAIL]` + `exit 1` |
| Health: 포트 | `ss -tln 'sport = :15034'` LISTEN 확인, 없으면 `[FAIL]` + `exit 1` |
| 방화벽 점검 | `systemctl is-active ufw`, 비활성 시 `[WARNING]` (계속 진행) |
| CPU | `/proc/stat` 1초 간격 차분 |
| MEM | `/proc/meminfo` `(MemTotal - MemAvailable)/MemTotal` |
| DISK | `df --output=pcent /` |
| 임계값 | CPU > 20, MEM > 10, DISK > 80 → `[WARNING]` |
| 로그 기록 | `/var/log/agent-app/monitor.log` 에 1라인 append, 포맷 `[YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..%` |
| 로그 회전 | 10MB 초과 시 `.1 ~ .10` 시프트, 11번째부터 삭제 (최대 10 파일) |

### 6.3 단독 실행 검증

```bash
# agent-admin 으로 직접 실행 (cron 등록 전 동작 확인)
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh
```

**기대 콘솔 출력 (예):**
```text
====== SYSTEM MONITOR RESULT ======

[HEALTH CHECK]
Checking process 'agent_app'... [OK] (PID: 48291)
Checking port 15034... [OK]

[RESOURCE MONITORING]
CPU Usage : 4.3%
MEM Usage : 5.2%
DISK Used : 23%

[INFO] Log appended: /var/log/agent-app/monitor.log
```

### 6.4 로그 누적 확인  ☑ 체크리스트 ⑦

```bash
tail -n 5 /var/log/agent-app/monitor.log
# 기대 (예):
#   [2026-05-26 14:00:01] PID:48291 CPU:4.3% MEM:5.2% DISK_USED:23%
```

> Health Check 실패(앱 미실행 / 포트 미LISTEN) 시나리오는 §5의 앱을 중지한 뒤 6.3을 다시 실행해 `[FAIL]` 출력과 `exit 1` 종료 코드 (`echo $?`) 를 확인해 검증할 수 있다. 검증 후 앱을 다시 띄워둔다.

---

## 7. cron 등록 (매분 실행)  ☑ 체크리스트 ⑧

### 7.1 agent-admin 소속 그룹 재확인

```bash
groups agent-admin | tr ' ' '\n' | grep -x agent-core
# 기대: agent-core (출력되어야 함)
```

> 빠져 있으면 `sudo usermod -aG agent-core agent-admin` 후 재로그인.

### 7.2 crontab 등록

```bash
sudo -u agent-admin bash -c '
    ( crontab -l 2>/dev/null | grep -v "monitor.sh" ; \
      echo "* * * * * /home/agent-admin/agent-app/bin/monitor.sh >> /tmp/monitor.cron.log 2>&1" \
    ) | crontab -
'
```

cron 환경은 PATH·환경 변수가 빈약하므로:
- monitor.sh 절대 경로 사용
- 표준출력/표준에러를 `/tmp/monitor.cron.log` 로 캡처 (문제 발생 시 디버깅용)
- monitor.sh 내부에서 `/etc/profile.d/agent-app.sh` 를 source 함

### 7.3 검증

```bash
# 등록 확인
sudo -u agent-admin crontab -l
# 기대 라인:
#   * * * * * /home/agent-admin/agent-app/bin/monitor.sh >> /tmp/monitor.cron.log 2>&1

# 1~2분 대기 후 로그 누적 확인
sleep 70
tail -n 3 /var/log/agent-app/monitor.log
# 기대: 직전 단계 6.4 보다 라인 수가 증가, 최근 타임스탬프가 현재 분(또는 직전 분) 에 해당

# cron 자체 로그도 함께 확인
tail -n 20 /tmp/monitor.cron.log
# 기대: 6.3 와 동일한 형식의 콘솔 출력이 1분마다 누적
```

---

## 8. 최종 체크리스트 검증

[MISSION.md §2.1](MISSION.md) 의 8개 체크박스를 그대로 따라 검증한다.

| # | 체크리스트 | 검증 명령 | 통과 기준 |
| --- | --- | --- | --- |
| ① | SSH 포트 20022 · root 차단 | `sudo sshd -T \| grep -Ei '^port\|^permitrootlogin'` | `port 20022` + `permitrootlogin no` |
| ② | UFW 활성 · 20022/15034 만 허용 | `sudo ufw status verbose` | `Status: active`, 두 포트만 ALLOW IN |
| ③ | 계정/그룹 생성 | `id agent-admin && id agent-dev && id agent-test && getent group agent-common agent-core` | 각 계정의 보조 그룹에 정책대로 매핑, 그룹 멤버 정확 |
| ④ | 디렉토리 구조 · 권한 (ACL 포함) | `ls -ld /home/agent-admin/agent-app/{upload_files,api_keys,bin} /var/log/agent-app` + `getfacl ...` | 표 §3.4 와 일치 |
| ⑤ | Boot Sequence 5/5 [OK] + "Agent READY" | §5.3 의 콘솔 출력 캡처 | 5단계 모두 `[OK]` + `Agent READY` |
| ⑥ | `monitor.sh` 실행 결과 | `sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh` | HEALTH OK + 리소스 라인 + (해당 시) WARNING |
| ⑦ | `monitor.log` 누적 | `tail -n 5 /var/log/agent-app/monitor.log` | 미션 §8 포맷의 라인이 존재 |
| ⑧ | crontab 매분 실행 · 자동 누적 | `sudo -u agent-admin crontab -l` + 1분 후 `tail` 비교 | 등록된 라인 일치 + 라인 수 증가 |

각 명령의 실행 결과를 캡처(스크린샷 또는 텍스트 복사)해 **요구사항 수행 내역서**에 첨부하면 미션 §2.1 의 산출물이 완성된다. `scripts/monitor.sh` 는 §2.2 의 두 번째 산출물로 그대로 제출한다.

---

## 부록 A. 트러블슈팅

| 증상 | 원인 / 조치 |
| --- | --- |
| `ufw enable` 직후 SSH 세션 끊김 | enable 전에 `ufw allow 20022/tcp` 가 빠짐. VM 콘솔에서 로그인 후 추가하고 재시도 (§2.1) |
| `sudo systemctl restart ssh` 후 22번도 계속 LISTEN | `ssh.socket` 이 살아 있어 socket activation 이 22 도 함께 연다. `sudo systemctl disable --now ssh.socket` 후 재시작 |
| Boot Sequence `[3/5] Checking Required Files [FAIL]` | `AGENT_KEY_PATH` 파일이 없거나 내용이 다름. §4.2 재실행 |
| Boot Sequence `[5/5] Verifying Log Permission [FAIL]` | `/var/log/agent-app` 의 그룹이 `agent-core` 가 아니거나 모드가 `2770` 아님. §3.4 (c) 재실행 후 agent-admin 재로그인 |
| `monitor.sh: Permission denied` (agent-admin 실행 시) | agent-admin 이 `agent-core` 그룹에 없거나 모드가 `750` 이 아님. `groups agent-admin` 와 `ls -l .../monitor.sh` 확인. 그룹 추가 후 **재로그인 필수** |
| cron 은 도는데 `monitor.log` 가 안 늘어남 | `/tmp/monitor.cron.log` 확인. 흔한 원인: 환경 변수 미로드(스크립트 내부 source 누락), `ss`/`pgrep` 절대경로 PATH 누락, 앱 미실행으로 인한 `exit 1` |
| `ss: sport = :15034` 가 항상 실패 | 앱이 실제로 `0.0.0.0:15034` 가 아닌 `127.0.0.1:15034` 로 바인딩됐는지 확인: `ss -tulnp \| grep 15034` |

## 부록 B. 빠른 참조

```bash
# 환경 변수 확인
sudo -iu agent-admin env | grep '^AGENT_'

# 앱 실행
sudo -iu agent-admin -- bash -lc '"$AGENT_HOME/agent_app"'

# monitor.sh 단독 실행
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh

# 로그 실시간 보기
sudo tail -f /var/log/agent-app/monitor.log

# cron 보기 / 편집
sudo -u agent-admin crontab -l
sudo -u agent-admin crontab -e

# 방화벽 상태
sudo ufw status verbose

# 권한 확인
ls -ld /home/agent-admin/agent-app/* /var/log/agent-app
getfacl /home/agent-admin/agent-app/api_keys
```
