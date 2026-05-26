# 요구사항 수행 내역서 — 시스템 관제 자동화 (B1-1)

본 문서는 [MISSION.md](MISSION.md) §2.1의 산출물 ①(요구사항 수행 내역서)이다. 미션 §4의 기능 요구사항을 [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) 의 절차에 따라 수행한 결과를, 8개 필수 증거 자료 체크리스트 단위로 정리한다.

각 절은 다음 4단 구조를 따른다.

1. **수행 내용** — 무엇을 했는지 1~2줄 요약
2. **수행 명령** — 적용한 핵심 명령(상세 절차는 [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) 의 해당 §를 참조)
3. **검증 명령 + 기대 출력** — 산출물로 제출할 증거의 형식
4. **실제 실행 결과** — 명령 실행 결과를 그대로 붙여넣는 자리

---

## 0. 환경 정보

| 항목 | 값 |
| --- | --- |
| 작성자 |  |
| 작성일 |  |
| OS | Ubuntu 22.04 LTS (x86_64) |
| 셸 | `bash` |
| 저장소 경로 | `~/Codyssey/B1-1` |
| `AGENT_HOME` | `/home/agent-admin/agent-app` |
| 참고 문서 | [MISSION.md](MISSION.md), [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) |
| 제공 바이너리 | `agent-app/agent-app-linux-x86` |

> 사전 패키지 설치는 [IMPLEMENTATION_GUIDE.md §0.3](IMPLEMENTATION_GUIDE.md) 을 참조한다(`openssh-server`, `ufw`, `cron`, `acl`, `iproute2`, `procps`, `coreutils`).

---

## 1. SSH 보안 설정 — 체크리스트 ①

**대응 요구사항**: [MISSION.md](MISSION.md) §4.1 SSH 설정 — 포트 `20022`, Root 원격 로그인 차단
**상세 절차**: [IMPLEMENTATION_GUIDE.md §1](IMPLEMENTATION_GUIDE.md)

### 1.1 수행 내용

`/etc/ssh/sshd_config` 의 `Port`·`PermitRootLogin` 값을 멱등하게 변경하고 `sshd` 를 재시작했다. Ubuntu 22.04 의 socket-activated SSH(`ssh.socket`)는 22번 포트로 추가 LISTEN 을 열 수 있으므로 비활성화했다.

### 1.2 수행 명령

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d)

sudo sed -i \
    -e 's/^#\?Port .*/Port 20022/' \
    -e 's/^#\?PermitRootLogin .*/PermitRootLogin no/' \
    /etc/ssh/sshd_config

grep -q '^Port 20022' /etc/ssh/sshd_config || \
    echo 'Port 20022' | sudo tee -a /etc/ssh/sshd_config

sudo systemctl disable --now ssh.socket 2>/dev/null || true
sudo systemctl restart ssh
```

### 1.3 검증 명령 + 기대 출력

```bash
sudo sshd -T | grep -Ei '^port|^permitrootlogin'
```

기대 출력:

```text
port 20022
permitrootlogin no
```

```bash
ss -tulnp | grep -E 'sshd|:20022'
```

기대 출력(예):

```text
tcp   LISTEN 0      128            0.0.0.0:20022      0.0.0.0:*    users:(("sshd",pid=...,fd=3))
```

### 1.4 실제 실행 결과

```text
# 실행 후 결과를 여기에 붙여넣으세요
```

---

## 2. 방화벽 설정 — 체크리스트 ②

**대응 요구사항**: [MISSION.md](MISSION.md) §4.1 방화벽 설정 — UFW, 인바운드 `20022/tcp`·`15034/tcp` 만 허용
**상세 절차**: [IMPLEMENTATION_GUIDE.md §2](IMPLEMENTATION_GUIDE.md)

### 2.1 수행 내용

`ufw enable` 직전에 SSH(`20022/tcp`)와 앱 포트(`15034/tcp`)를 먼저 허용해 락아웃을 방지했다. 기본 정책은 인바운드 deny / 아웃바운드 allow.

### 2.2 수행 명령

```bash
sudo ufw allow 20022/tcp comment 'SSH (custom)'
sudo ufw allow 15034/tcp comment 'agent-app'
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable
```

### 2.3 검증 명령 + 기대 출력

```bash
sudo ufw status verbose
```

기대 출력(요지):

```text
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

`Status: active` 와 위 4개 라인 외에 다른 인바운드 `ALLOW` 가 없어야 한다.

### 2.4 실제 실행 결과

```text
# 실행 후 결과를 여기에 붙여넣으세요
```

---

## 3. 계정 / 그룹 생성 — 체크리스트 ③

**대응 요구사항**: [MISSION.md](MISSION.md) §4.2 — `agent-admin`/`agent-dev`/`agent-test` + `agent-common`/`agent-core`
**상세 절차**: [IMPLEMENTATION_GUIDE.md §3.1~§3.2](IMPLEMENTATION_GUIDE.md)

### 3.1 수행 내용

| 그룹 | 소속 계정 |
| --- | --- |
| `agent-common` | `agent-admin`, `agent-dev`, `agent-test` |
| `agent-core`   | `agent-admin`, `agent-dev` |

### 3.2 수행 명령

```bash
sudo groupadd -f agent-common
sudo groupadd -f agent-core

sudo useradd -m -s /bin/bash -G agent-common,agent-core agent-admin
sudo useradd -m -s /bin/bash -G agent-common,agent-core agent-dev
sudo useradd -m -s /bin/bash -G agent-common               agent-test
```

### 3.3 검증 명령 + 기대 출력

```bash
id agent-admin
id agent-dev
id agent-test
getent group agent-common agent-core
```

기대 출력(예):

```text
uid=1001(agent-admin) gid=1001(agent-admin) groups=1001(agent-admin),1004(agent-common),1005(agent-core)
uid=1002(agent-dev)   gid=1002(agent-dev)   groups=1002(agent-dev),1004(agent-common),1005(agent-core)
uid=1003(agent-test)  gid=1003(agent-test)  groups=1003(agent-test),1004(agent-common)

agent-common:x:1004:agent-admin,agent-dev,agent-test
agent-core:x:1005:agent-admin,agent-dev
```

- `agent-admin`, `agent-dev` 의 보조 그룹에 `agent-common` 과 `agent-core` 가 **모두** 포함되어야 한다.
- `agent-test` 의 보조 그룹은 `agent-common` **만** 포함, `agent-core` 는 제외되어야 한다.

### 3.4 실제 실행 결과

```text
# 실행 후 결과를 여기에 붙여넣으세요
```

---

## 4. 디렉토리 구조 및 권한 (ACL 포함) — 체크리스트 ④

**대응 요구사항**: [MISSION.md](MISSION.md) §4.2 디렉토리/접근 권한 표
**상세 절차**: [IMPLEMENTATION_GUIDE.md §3.3~§3.4](IMPLEMENTATION_GUIDE.md)

### 4.1 수행 내용

`$AGENT_HOME` 하위에 `bin`/`upload_files`/`api_keys` 와 시스템 로그 위치 `/var/log/agent-app` 를 생성하고, 그룹 소유 + setgid(2770) + default ACL 로 협업/최소권한 정책을 구현했다.

| 디렉토리 | 소유자 | 그룹 | 모드 | 기본 ACL |
| --- | --- | --- | --- | --- |
| `$AGENT_HOME/upload_files` | `agent-admin` | `agent-common` | `2770` | `g:agent-common:rwx` |
| `$AGENT_HOME/api_keys`     | `agent-admin` | `agent-core`   | `2770` | `g:agent-core:rwx` |
| `$AGENT_HOME/bin`          | `agent-admin` | `agent-core`   | `2750` | — |
| `/var/log/agent-app`       | `root`        | `agent-core`   | `2770` | `g:agent-core:rwx` |

### 4.2 수행 명령

```bash
sudo -u agent-admin mkdir -p /home/agent-admin/agent-app/{bin,upload_files,api_keys}
sudo mkdir -p /var/log/agent-app

# upload_files : agent-common 공유 R/W
sudo chown agent-admin:agent-common /home/agent-admin/agent-app/upload_files
sudo chmod 2770                     /home/agent-admin/agent-app/upload_files
sudo setfacl -d -m g:agent-common:rwx /home/agent-admin/agent-app/upload_files

# api_keys : agent-core 만 R/W
sudo chown agent-admin:agent-core /home/agent-admin/agent-app/api_keys
sudo chmod 2770                   /home/agent-admin/agent-app/api_keys
sudo setfacl -d -m g:agent-core:rwx /home/agent-admin/agent-app/api_keys

# /var/log/agent-app : agent-core 만 R/W
sudo chown root:agent-core   /var/log/agent-app
sudo chmod 2770              /var/log/agent-app
sudo setfacl -d -m g:agent-core:rwx /var/log/agent-app

# bin
sudo chown agent-admin:agent-core /home/agent-admin/agent-app/bin
sudo chmod 2750                   /home/agent-admin/agent-app/bin
```

### 4.3 검증 명령 + 기대 출력

```bash
ls -ld /home/agent-admin/agent-app \
       /home/agent-admin/agent-app/upload_files \
       /home/agent-admin/agent-app/api_keys \
       /home/agent-admin/agent-app/bin \
       /var/log/agent-app
```

기대 출력(요지):

```text
drwxr-xr-x agent-admin agent-admin   .../agent-app
drwxrws--- agent-admin agent-common  .../agent-app/upload_files
drwxr-s--- agent-admin agent-core    .../agent-app/api_keys
drwxr-s--- agent-admin agent-core    .../agent-app/bin
drwxrws--- root        agent-core    /var/log/agent-app
```

```bash
getfacl /home/agent-admin/agent-app/upload_files
getfacl /home/agent-admin/agent-app/api_keys
getfacl /var/log/agent-app
```

기대 출력에 다음 default ACL 라인이 포함되어야 한다.

```text
default:group:agent-common:rwx   # upload_files
default:group:agent-core:rwx     # api_keys, /var/log/agent-app
```

### 4.4 실제 실행 결과

```text
# 실행 후 결과를 여기에 붙여넣으세요
```

---

## 5. 환경 변수 및 키 파일

> 본 절은 8개 체크리스트의 직접 항목은 아니지만, **체크리스트 ⑤(Boot Sequence)** 통과의 사전 조건이므로 함께 기록한다.
**상세 절차**: [IMPLEMENTATION_GUIDE.md §4](IMPLEMENTATION_GUIDE.md)

### 5.1 수행 내용

`/etc/profile.d/agent-app.sh` 에 `AGENT_*` 환경 변수를 시스템 전역으로 등록하고, `agent_api_key_test` 1줄을 담은 키 파일을 `$AGENT_KEY_PATH` 에 생성했다.

### 5.2 수행 명령

```bash
sudo tee /etc/profile.d/agent-app.sh >/dev/null <<'EOF'
export AGENT_HOME="/home/agent-admin/agent-app"
export AGENT_PORT="15034"
export AGENT_UPLOAD_DIR="$AGENT_HOME/upload_files"
export AGENT_KEY_PATH="$AGENT_HOME/api_keys/t_secret.key"
export AGENT_LOG_DIR="/var/log/agent-app"
EOF
sudo chmod 644 /etc/profile.d/agent-app.sh

sudo -u agent-admin bash -lc '
    printf "agent_api_key_test\n" > "$AGENT_KEY_PATH"
    chmod 640 "$AGENT_KEY_PATH"
'
```

### 5.3 검증 명령 + 기대 출력

```bash
sudo -iu agent-admin env | grep '^AGENT_'
```

기대 출력:

```text
AGENT_HOME=/home/agent-admin/agent-app
AGENT_PORT=15034
AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files
AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys/t_secret.key
AGENT_LOG_DIR=/var/log/agent-app
```

```bash
sudo -u agent-admin cat /home/agent-admin/agent-app/api_keys/t_secret.key
ls -l /home/agent-admin/agent-app/api_keys/t_secret.key
```

기대 출력:

```text
agent_api_key_test
-rw-r----- 1 agent-admin agent-core ... t_secret.key
```

### 5.4 실제 실행 결과

```text
# 실행 후 결과를 여기에 붙여넣으세요
```

---

## 6. 앱 Boot Sequence — 체크리스트 ⑤

**대응 요구사항**: [MISSION.md](MISSION.md) §4.3 — 일반 계정 실행, 5단계 `[OK]` + "Agent READY", `0.0.0.0:15034` LISTEN
**상세 절차**: [IMPLEMENTATION_GUIDE.md §5](IMPLEMENTATION_GUIDE.md)

### 6.1 수행 내용

[scripts/monitor.sh](../scripts/monitor.sh) 가 `pgrep -f 'agent_app'` 로 프로세스를 식별하므로, 제공 바이너리를 `agent_app` 로 rename 해 `$AGENT_HOME/agent_app` 에 배치했다. `agent-admin` 으로 포어그라운드 실행해 Boot Sequence 를 확인한다.

### 6.2 수행 명령

```bash
sudo install -o agent-admin -g agent-core -m 0750 \
    ~/Codyssey/B1-1/agent-app/agent-app-linux-x86 \
    /home/agent-admin/agent-app/agent_app

# 별도 터미널에서 포어그라운드 실행
sudo -iu agent-admin -- bash -lc '"$AGENT_HOME/agent_app"'
```

### 6.3 검증 명령 + 기대 출력

콘솔에 5단계 모두 `[OK]` 와 마지막 줄에 `Agent READY` 가 출력되어야 한다.

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

별도 터미널에서 LISTEN 포트를 확인한다.

```bash
ss -tulnp | grep ':15034'
```

기대 출력(예):

```text
tcp   LISTEN 0     ...     0.0.0.0:15034     0.0.0.0:*     users:(("agent_app",pid=...,fd=...))
```

### 6.4 실제 실행 결과

**Boot Sequence 콘솔 출력**

```text
# 실행 후 결과를 여기에 붙여넣으세요
```

**포트 LISTEN 확인**

```text
# 실행 후 결과를 여기에 붙여넣으세요
```

---

## 7. `monitor.sh` 실행 결과 — 체크리스트 ⑥

**대응 요구사항**: [MISSION.md](MISSION.md) §4.4 — Health Check, 방화벽 점검, 자원 수집, 임계값 경고, 로그 기록
**상세 절차**: [IMPLEMENTATION_GUIDE.md §6](IMPLEMENTATION_GUIDE.md)
**스크립트 소스**: [scripts/monitor.sh](../scripts/monitor.sh)

### 7.1 수행 내용

저장소의 [scripts/monitor.sh](../scripts/monitor.sh) 를 `$AGENT_HOME/bin/monitor.sh` 로 배치(소유자 `agent-dev`, 그룹 `agent-core`, 모드 `0750`)하고, `agent-admin` 으로 단독 실행해 동작을 검증했다.

### 7.2 수행 명령

```bash
sudo install -o agent-dev -g agent-core -m 0750 \
    ~/Codyssey/B1-1/scripts/monitor.sh \
    /home/agent-admin/agent-app/bin/monitor.sh

sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh
```

### 7.3 검증 명령 + 기대 출력

`monitor.sh` 는 다음 형식으로 출력한다([scripts/monitor.sh:135-170](../scripts/monitor.sh#L135-L170)).

```text
====== SYSTEM MONITOR RESULT ======

[HEALTH CHECK]
Checking process 'agent_app'... [OK] (PID: <pid>)
Checking port 15034... [OK]

[RESOURCE MONITORING]
CPU Usage : <n>%
MEM Usage : <n>%
DISK Used : <n>%

[INFO] Log appended: /var/log/agent-app/monitor.log
```

임계값(CPU > 20%, MEM > 10%, DISK > 80%) 초과 시 `RESOURCE MONITORING` 블록 뒤에 다음 라인이 추가된다.

```text
[WARNING] CPU threshold exceeded (<n>% > 20%)
[WARNING] MEM threshold exceeded (<n>% > 10%)
[WARNING] DISK threshold exceeded (<n>% > 80%)
```

UFW 가 비활성 상태이면 `HEALTH CHECK` 블록 끝에 다음이 추가된다(스크립트는 종료하지 않음).

```text
[WARNING] UFW is not active
```

배치 직후 권한도 함께 확인한다.

```bash
ls -l /home/agent-admin/agent-app/bin/monitor.sh
```

기대 출력:

```text
-rwxr-x--- 1 agent-dev agent-core ... monitor.sh
```

### 7.4 실제 실행 결과

**`monitor.sh` 콘솔 출력**

```text
# 실행 후 결과를 여기에 붙여넣으세요
```

**파일 권한 확인**

```text
# 실행 후 결과를 여기에 붙여넣으세요
```

---

## 8. `monitor.log` 누적 기록 — 체크리스트 ⑦

**대응 요구사항**: [MISSION.md](MISSION.md) §4.4 로그 기록 — `/var/log/agent-app/monitor.log` 에 정해진 포맷으로 1줄 append
**상세 절차**: [IMPLEMENTATION_GUIDE.md §6.4](IMPLEMENTATION_GUIDE.md)

### 8.1 수행 내용

`monitor.sh` 실행 시마다 `/var/log/agent-app/monitor.log` 에 1줄이 추가되며, 파일이 10 MiB 를 초과하면 `.1`~`.10` 로 회전하고 11번째 파일부터 삭제된다([scripts/monitor.sh:104-122](../scripts/monitor.sh#L104-L122)).

### 8.2 검증 명령 + 기대 출력

```bash
tail -n 5 /var/log/agent-app/monitor.log
```

기대 포맷([scripts/monitor.sh:167](../scripts/monitor.sh#L167)):

```text
[YYYY-MM-DD HH:MM:SS] PID:<pid> CPU:<n>% MEM:<n>% DISK_USED:<n>%
```

기대 출력(예):

```text
[2026-05-26 14:00:01] PID:48291 CPU:4.3% MEM:5.2% DISK_USED:23%
```

### 8.3 실제 실행 결과

```text
# 실행 후 결과를 여기에 붙여넣으세요
```

---

## 9. crontab 매분 실행 — 체크리스트 ⑧

**대응 요구사항**: [MISSION.md](MISSION.md) §4.5 — `agent-admin` 의 crontab으로 `monitor.sh` 매분 실행, 1~2분 내 로그 누적 확인
**상세 절차**: [IMPLEMENTATION_GUIDE.md §7](IMPLEMENTATION_GUIDE.md)

### 9.1 수행 내용

`agent-admin` 이 `agent-core` 그룹에 포함된 것을 확인한 뒤, 매분 실행되는 cron 라인을 등록했다. 표준출력/표준에러는 디버깅을 위해 `/tmp/monitor.cron.log` 로 별도 캡처한다.

### 9.2 수행 명령

```bash
groups agent-admin | tr ' ' '\n' | grep -x agent-core   # 사전 확인

sudo -u agent-admin bash -c '
    ( crontab -l 2>/dev/null | grep -v "monitor.sh" ; \
      echo "* * * * * /home/agent-admin/agent-app/bin/monitor.sh >> /tmp/monitor.cron.log 2>&1" \
    ) | crontab -
'
```

### 9.3 검증 명령 + 기대 출력

**(1) 등록 라인 확인**

```bash
sudo -u agent-admin crontab -l
```

기대 출력:

```text
* * * * * /home/agent-admin/agent-app/bin/monitor.sh >> /tmp/monitor.cron.log 2>&1
```

**(2) 등록 직후 로그 라인 수 기록**

```bash
wc -l /var/log/agent-app/monitor.log
```

**(3) 1~2분 대기 후 라인 증가 확인**

```bash
sleep 70
wc -l /var/log/agent-app/monitor.log
tail -n 3 /var/log/agent-app/monitor.log
```

기대: (3) 의 라인 수가 (2) 보다 **증가**해야 하며, 가장 최근 타임스탬프가 직전 분 또는 현재 분에 해당해야 한다.

**(4) cron 콘솔 출력 캡처 확인**

```bash
tail -n 20 /tmp/monitor.cron.log
```

기대: §7.3 과 동일한 형식의 `monitor.sh` 콘솔 출력이 1분 간격으로 누적된다.

### 9.4 실제 실행 결과

**crontab 등록 라인**

```text
# 실행 후 결과를 여기에 붙여넣으세요
```

**등록 직후 → 1~2분 후 로그 라인 증가**

```text
# (등록 직후) wc -l 출력
# (1~2분 후) wc -l 출력
# (1~2분 후) tail -n 3 출력
```

**`/tmp/monitor.cron.log` 누적**

```text
# 실행 후 결과를 여기에 붙여넣으세요
```

---

## 10. 최종 체크리스트

[MISSION.md §2.1](MISSION.md) 의 8개 필수 증거 자료 체크리스트. 각 항목은 본 문서의 해당 §에서 명령·기대 출력·실제 결과를 함께 확인할 수 있다.

- [ ] SSH 포트 변경(`20022`) 및 Root 원격 접속 차단 설정 확인 내역 — [§1](#1-ssh-보안-설정--체크리스트-)
- [ ] 방화벽(UFW 또는 firewalld) 활성화 및 `20022/tcp`, `15034/tcp`만 허용 내역 — [§2](#2-방화벽-설정--체크리스트-)
- [ ] 계정/그룹(`agent-admin`/`dev`/`test`, `agent-common`/`core`) 생성 확인 내역 — [§3](#3-계정--그룹-생성--체크리스트-)
- [ ] 디렉토리 구조 및 권한(ACL 포함) 확인 내역 — [§4](#4-디렉토리-구조-및-권한-acl-포함--체크리스트-)
- [ ] 앱 Boot Sequence 5단계 `[OK]` 및 "Agent READY" 확인 내역 — [§6](#6-앱-boot-sequence--체크리스트-)
- [ ] `monitor.sh` 실행 결과(프로세스/포트/리소스/경고) 내역 — [§7](#7-monitorsh-실행-결과--체크리스트-)
- [ ] `/var/log/agent-app/monitor.log` 누적 기록 확인(최근 라인) 내역 — [§8](#8-monitorlog-누적-기록--체크리스트-)
- [ ] crontab 매분 실행 등록 및 자동 실행 확인(1분 후 로그 증가) 내역 — [§9](#9-crontab-매분-실행--체크리스트-)

모든 항목의 "실제 실행 결과" 블록이 채워지고 위 8개 체크박스가 모두 `[x]` 가 되면 [MISSION.md](MISSION.md) §2.1 산출물 ①(요구사항 수행 내역서)이 완성된다. 두 번째 산출물 ②(`monitor.sh`)는 [scripts/monitor.sh](../scripts/monitor.sh) 를 그대로 제출한다.
