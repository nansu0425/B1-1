# B1-1 명령어 레퍼런스 — 모든 명령의 의미와 플래그

본 문서는 [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) 의 모든 명령 한 줄 한 줄에 대해 **"무엇을 하는가"·"왜 거기 그 플래그가 붙어 있는가"** 를 설명한다. 실행 순서·전체 그림은 IMPLEMENTATION_GUIDE 를, 설계 이유·미션 §3 학습 목표 답변은 [STUDY_GUIDE.md](STUDY_GUIDE.md) 를 참조한다.

---

## 0. 이 문서의 사용법

### 0.1 도구 위계

이 미션에서 쓰는 명령은 출처가 다양하다. 어디서 왔는지 알면 매뉴얼을 찾을 때 헷갈리지 않는다.

| 분류 | 대표 명령 | 특징 |
|---|---|---|
| 셸 빌트인(bash) | `cd`, `echo`, `printf`, `read`, `[[ ]]`, `(( ))`, `for/while`, `local` | bash 프로세스 안에서 직접 실행 — `man bash` |
| GNU coreutils | `cp`, `mv`, `cat`, `tail`, `head`, `ls`, `chmod`, `chown`, `tee`, `tr`, `wc`, `df`, `stat` | 거의 모든 리눅스 기본 — `man 1 <명령>` |
| 텍스트 처리 | `sed`, `awk`, `grep` | 정규식 + 스트림 변환의 표준 도구 |
| 시스템 관리 | `sudo`, `systemctl`, `useradd`, `groupadd`, `usermod`, `id`, `groups`, `getent` | 사용자/서비스 관리. 대부분 root 권한 필요 |
| 네트워크 | `ss`, `ufw` | `ss` 는 `netstat` 의 후속(iproute2 패키지). `ufw` 는 iptables 프런트엔드 |
| ACL | `setfacl`, `getfacl` | POSIX ACL. `acl` 패키지 |
| 스케줄러 | `cron`, `crontab` | `cron` 은 데몬, `crontab` 은 사용자별 등록 도구 |
| SSH | `sshd`, `ssh`, `sshd_config` | OpenSSH. `man sshd_config` 가 옵션 사전 |
| 패키지 | `apt`, `apt-get`, `dpkg` | Debian/Ubuntu 의 패키지 매니저 |

### 0.2 모든 § 에서 반복되는 셸 패턴

본문에서 매번 설명하지 않도록 한 번만 정리한다.

#### `sudo` 의 3가지 모드

```bash
sudo CMD                    # (a) root 권한으로 CMD 실행 (현재 env 일부 유지)
sudo -u USER CMD            # (b) USER 권한으로 CMD 실행 (env 유지)
sudo -iu USER -- bash -lc 'CMD'   # (c) USER 의 로그인 셸로 CMD 실행 (env 초기화)
```

| 모드 | 효과 | 언제 쓰나 |
|---|---|---|
| (a) | uid=0, 환경 일부 유지 | 시스템 변경 (apt, systemctl, useradd 등) |
| (b) | uid=USER, 환경 유지 | 특정 사용자 권한으로 빠르게 단발 명령 |
| (c) | uid=USER, **로그인 셸** 초기화 (`/etc/profile`, `~/.bashrc` source) | 로그인된 것처럼 동작해야 할 때 — 환경 변수가 시스템 전역에서 제대로 들어오는지 검증 |

> `sudo -n` 은 "비대화" 모드 — 비밀번호가 필요하면 즉시 실패. 스크립트에서 NOPASSWD 가용성 체크에 유용.

#### `"$VAR"` vs `'$VAR'`

```bash
echo "$AGENT_HOME"   # /home/agent-admin/agent-app  ← 큰따옴표는 변수 expansion
echo '$AGENT_HOME'   # $AGENT_HOME                  ← 작은따옴표는 리터럴, expansion 차단
```

`sed` 의 패턴이나 heredoc 의 종료 토큰에서 expansion 을 막고 싶을 때 작은따옴표를 쓴다.

#### `$(...)` 명령 치환

```bash
DATE=$(date +%Y%m%d)         # date 명령의 stdout 을 DATE 변수에 담음
sudo cp F F.bak.$(date ...)  # 명령 결과를 문자열 자리에 끼워넣음
```

백틱 `` `cmd` `` 도 같은 의미지만 중첩이 어려워 `$()` 가 표준이다.

#### `<<'EOF' ... EOF` heredoc

```bash
sudo tee /etc/profile.d/agent-app.sh >/dev/null <<'EOF'
export AGENT_HOME="..."
EOF
```

- `<<EOF` 는 stdin 으로 EOF 까지의 텍스트 블록을 보내는 문법.
- 종료 토큰을 **작은따옴표** 로 감싸면(`<<'EOF'`) heredoc 내부의 `$VAR`/`$(...)` 가 expand 되지 않는다 — 그래서 `export AGENT_HOME="$AGENT_HOME/x"` 가 글자 그대로 파일에 기록된다.

#### 리다이렉션

| 기호 | 의미 |
|---|---|
| `> FILE` | stdout 을 FILE 로 (덮어쓰기) |
| `>> FILE` | stdout 을 FILE 끝에 append |
| `2> FILE` | stderr 만 FILE 로 |
| `2>&1` | stderr 를 stdout 이 가는 곳으로 합침 (`>> LOG 2>&1` = 둘 다 LOG 에 append) |
| `< FILE` | stdin 을 FILE 에서 |
| `<<<"text"` | "text" 를 stdin 으로 (here-string) |

#### `|`, `&&`, `||`, `;`

| 연산자 | 의미 |
|---|---|
| `A \| B` | A 의 stdout 을 B 의 stdin 으로 파이프 |
| `A && B` | A 가 **성공(exit 0)** 하면 B 실행 |
| `A \|\| B` | A 가 **실패(exit ≠ 0)** 하면 B 실행 |
| `A ; B` | A 의 성공/실패와 무관하게 B 실행 |

#### exit code

- `0` = 성공, `1` 이상 = 실패. 셸은 마지막 명령의 exit code 를 `$?` 에 담는다.
- 스크립트 안에서 `exit 1` 로 명시적으로 실패 신호를 보낼 수 있다 — monitor.sh 의 Health Check 가 그 예.

#### 비대화 플래그

| 플래그 | 도구 | 의미 |
|---|---|---|
| `-y` | apt | "정말로?" 확인 프롬프트에 자동 yes |
| `--force` | ufw | enable 시 "정말 활성화?" 프롬프트 스킵 |
| `-q` / `--quiet` | apt-get, systemctl 등 | 출력 최소화 |
| `-f` | groupadd | 이미 존재해도 에러 내지 않음 (idempotent) |

스크립트화하려면 모든 대화형 프롬프트를 위 플래그로 막아야 한다.

---

## 1. 패키지 설치 ([IG §0.3](IMPLEMENTATION_GUIDE.md))

### 1.1 `sudo apt update`

```bash
sudo apt update
```

**의미**: 시스템의 패키지 인덱스(어떤 패키지의 어떤 버전이 저장소에 있는지 목록) 를 최신화한다. `/var/lib/apt/lists/` 아래 캐시 갱신.

**왜**: 다음 단계의 `apt install` 이 오래된 인덱스로 옛 버전을 깔거나 "package not found" 오류를 내지 않게 하기 위함. 새 VM 이나 오랫동안 update 안 한 시스템에서는 거의 필수.

**플래그 없음** — 그러나 `apt` 대신 스크립트 친화적인 `apt-get update -qq` 를 쓰는 경우도 있다(`-qq` = 매우 조용).

### 1.2 `sudo apt install -y openssh-server ufw cron acl iproute2 procps coreutils`

```bash
sudo apt install -y openssh-server ufw cron acl iproute2 procps coreutils
```

**의미**: 7개 패키지를 한 번에 설치. 이미 설치돼 있으면 "이미 최신" 으로 끝남.

**왜**: 이번 미션이 쓰는 모든 도구의 출처. 각각 어떤 명령을 제공하는지:

| 패키지 | 제공하는 명령 | 미션에서의 용도 |
|---|---|---|
| `openssh-server` | `sshd`, `sshd_config` | SSH 서버. 포트 20022 |
| `ufw` | `ufw` | 방화벽 프런트엔드 |
| `cron` | `cron`, `crontab` | 매분 모니터링 자동 실행 |
| `acl` | `setfacl`, `getfacl` | default ACL 적용 |
| `iproute2` | `ss`, `ip` | 포트 LISTEN 확인 |
| `procps` | `pgrep`, `ps` | agent_app 프로세스 식별 |
| `coreutils` | `cp`, `chmod`, `chown`, `tee`, `df` 등 | 거의 모든 기본 파일 조작 |

**플래그**:
- `-y` — 모든 확인 프롬프트("Do you want to continue? [Y/n]") 에 자동 yes. 비대화 자동화에 필수. 안 붙이면 cron 으로 돌릴 때 stdin 이 없어 hang 됨.

### 1.3 `sudo systemctl enable --now ssh`

```bash
sudo systemctl enable --now ssh
```

**의미**: `ssh.service` 를 **부팅 시 자동 시작** 으로 등록하고(`enable`), **지금 즉시 시작**(`--now`).

**왜**: `apt install openssh-server` 가 패키지를 까지만, 자동으로 enable+start 되지 않는 경우가 있다(특히 컨테이너 이미지). 두 동작을 한 번에 보장.

**플래그**:
- `enable` — `/etc/systemd/system/multi-user.target.wants/` 아래 심볼릭 링크 추가 → 부팅 시 활성화
- `--now` — `enable` 과 동시에 `start` 도 — 두 번 호출(`enable` + `start`) 안 해도 됨
- 인자 `ssh` — `ssh.service` 의 줄임. systemd 가 `.service` 를 자동 추론

### 1.4 `sudo systemctl enable --now cron`

```bash
sudo systemctl enable --now cron
```

**의미·왜**: §1.3 와 동일하되 대상이 `cron.service`. 이게 안 떠 있으면 §10 의 crontab 등록은 되지만 **실제로 도는 사람이 없어** monitor.log 가 안 늘어난다.

### 1.5 `file ~/Codyssey/B1-1/agent-app/agent-app-linux-x86`

```bash
file ~/Codyssey/B1-1/agent-app/agent-app-linux-x86
```

**의미**: 파일의 종류(ELF? script? data?)를 magic number 로 판별해 출력. 우리 케이스에서는 `ELF 64-bit LSB executable, x86-64 ...` 라 나와야 함.

**왜**: 다른 플랫폼용 바이너리(arm64) 를 잘못 받았는지 사전 검증. arm64 바이너리는 x86 VM 에서 `Exec format error` 로 실패.

**플래그 없음**. 인자가 디렉토리면 안의 모든 파일을, 파일이면 그 파일만 판별.

---

## 2. SSH 보안 설정 ([IG §1](IMPLEMENTATION_GUIDE.md))

### 2.1 `sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d)`

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d)
```

**의미**: `sshd_config` 를 같은 디렉토리에 `sshd_config.bak.20260528` 같은 이름으로 복사. `$(date +%Y%m%d)` 는 [§0.2 명령 치환](#02-) 으로 현재 날짜를 끼워넣는다.

**왜**: sshd 설정은 한 글자만 틀려도 sshd 가 안 떠 SSH 락아웃이 발생한다. 백업이 있으면 `sudo cp .bak ... sshd_config && sudo systemctl restart ssh` 로 원상복구 가능. 날짜를 파일명에 박아두면 여러 번 수정해도 히스토리가 남음.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `sudo` | root 권한 필요 — `/etc/ssh/` 는 root 소유 |
| `cp` | copy. 옵션 없으면 단순 복사 (`-p` 로 권한·timestamp 도 보존 가능) |
| `+%Y%m%d` | `date` 의 strftime 포맷. `%Y`=4자리 연도, `%m`=2자리 월, `%d`=2자리 일 |

### 2.2 `sudo sed -i -e '...' -e '...' /etc/ssh/sshd_config`

```bash
sudo sed -i \
    -e 's/^#\?Port .*/Port 20022/' \
    -e 's/^#\?PermitRootLogin .*/PermitRootLogin no/' \
    /etc/ssh/sshd_config
```

**의미**: sshd_config 파일 안의 `Port ...` 라인과 `PermitRootLogin ...` 라인을 각각 `Port 20022`, `PermitRootLogin no` 로 **그 자리에서** 치환. 행 앞에 `#` 주석이 있어도 함께 매치.

**왜**: 같은 일을 vi 로 손편집할 수도 있지만, sed 로 자동화하면 **멱등**(여러 번 실행해도 결과 동일) 하고 재현 가능. `#?` 가 핵심 — Ubuntu 의 sshd_config 는 보통 `#Port 22` 처럼 주석 처리된 기본값이 있다. 주석이 있든 없든 잡으려면 `#?` (0 또는 1번) 필요.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `-i` | **in-place** 편집. 원본 파일을 직접 수정 (`-i.bak` 처럼 인자 주면 자동 백업도 가능) |
| `-e EXPR` | 적용할 sed 스크립트. 여러 `-e` 로 여러 치환을 한 번에 |
| `s/PAT/REP/` | substitute — sed 의 가장 기본 명령 |
| `^` | 정규식 anchor — 행 시작 |
| `\?` | 직전 문자(`#`) 가 0 또는 1번. `?` 자체를 정규식 메타로 쓰려면 `\` 이스케이프 (basic regex). |
| `.*` | 모든 문자 0회 이상 — 뒤따르는 값(`22`, `prohibit-password` 등) 다 매치 |

> sed 의 정규식은 기본(BRE) 과 확장(ERE, `-E`) 두 가지가 있다. `-E` 면 `\?` 가 그냥 `?` 로 됨.

### 2.3 `grep -q '^Port 20022' ... || echo 'Port 20022' | sudo tee -a ...`

```bash
grep -q '^Port 20022' /etc/ssh/sshd_config || \
    echo 'Port 20022' | sudo tee -a /etc/ssh/sshd_config
```

**의미**: sshd_config 에 `Port 20022` 라인이 **있는지 확인**하고, **없으면** 파일 끝에 추가.

**왜**: §2.2 의 sed 가 안전망이긴 하지만, 만약 원본에 `Port ` 라인 자체가 아예 없으면 sed 가 치환할 게 없어 아무 일도 안 한다. 이 fallback 으로 "어떤 경우든 결과적으로 `Port 20022` 가 존재" 를 보장 — 진정한 멱등성.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `grep -q` | quiet. 매칭 결과 출력 안 함. exit code 만 사용 (있으면 0, 없으면 1) |
| `^Port 20022` | 행 시작이 정확히 "Port 20022" |
| `\|\|` | [§0.2](#02-) — 앞 명령이 **실패** 했을 때만 뒤 실행 |
| `echo 'Port 20022'` | 문자열을 stdout 으로 (큰따옴표/작은따옴표 차이 없음 — 변수 없음) |
| `\|` | 파이프 — echo 의 stdout 을 tee 의 stdin 으로 |
| `tee -a FILE` | stdin 을 stdout + FILE 양쪽에 — `-a` 는 append (없으면 덮어씀) |
| `sudo tee` | `>` 는 셸 리다이렉션이라 sudo 가 안 통한다 — 그래서 `sudo tee` 패턴이 root 파일에 쓰는 표준 방법 |

### 2.4 `sudo systemctl disable --now ssh.socket 2>/dev/null || true`

```bash
sudo systemctl disable --now ssh.socket 2>/dev/null || true
```

**의미**: `ssh.socket` 을 비활성화하고 지금 중지. 에러는 무시.

**왜**: Ubuntu 22.04 는 sshd 를 두 가지 방식으로 띄울 수 있다 — (a) `ssh.service` 가 항상 LISTEN, (b) `ssh.socket` 이 LISTEN 하다가 연결 들어오면 sshd 를 spawn(socket activation). (b) 가 활성화돼 있으면 우리가 `ssh.service` 의 포트를 20022 로 바꿔도 socket 이 22 를 따로 LISTEN 해 충돌·이중 LISTEN 이 발생. 안전하게 (b) 를 끈다.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `disable` | 부팅 시 자동 시작 비활성화 |
| `--now` | 현재도 즉시 중지 |
| `ssh.socket` | systemd 의 .socket unit (사실상 inetd 의 systemd 버전) |
| `2>/dev/null` | stderr 를 /dev/null 로 (에러 메시지 안 보이게) |
| `\|\| true` | 명령이 실패해도 (예: ssh.socket 이 애초에 없는 시스템) 셸 전체가 실패하지 않게 |

### 2.5 `sudo systemctl restart ssh`

```bash
sudo systemctl restart ssh
```

**의미**: `ssh.service` 를 중지 후 재시작. 새로운 설정을 다시 읽음.

**왜**: §2.2 의 sed 가 sshd_config 를 바꿨어도, sshd 데몬은 **시작할 때 한 번만** 설정을 읽는다. `restart` 없이는 변경이 반영되지 않음. `reload` (HUP 시그널) 로도 되지만 sshd 가 `Port` 변경은 reload 로 못 받는 경우가 있어 `restart` 가 안전.

**플래그 없음**. 인자만 `ssh`.

### 2.6 `sudo systemctl status ssh --no-pager`

```bash
sudo systemctl status ssh --no-pager
```

**의미**: ssh.service 의 상태(active/failed, PID, recent log 등) 를 출력.

**왜**: §2.5 의 restart 가 진짜 성공했는지 즉시 확인. 실패면 `Active: failed` 와 함께 마지막 에러가 보임.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `status` | 상태 조회 (실행 안 함) |
| `--no-pager` | 출력이 `less` 같은 pager 로 가지 않고 stdout 으로 직출력. 스크립트에서 멈춤 방지 |

### 2.7 `sudo sshd -T | grep -Ei '^port|^permitrootlogin'`

```bash
sudo sshd -T | grep -Ei '^port|^permitrootlogin'
```

**의미**: sshd 가 **현재 실제로 적용하고 있는** 설정 전체를 출력하고, 거기서 `port` / `permitrootlogin` 라인만 추출.

**왜**: sshd_config 파일을 직접 grep 하면 주석이나 미반영 변경을 잡을 수 있다. `sshd -T` 는 sshd 가 시작했을 때 해석한 결과(effective config) 라 가장 신뢰 가능.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `-T` | sshd 의 test 모드 — 실제 데몬은 띄우지 않고 설정만 파싱·dump |
| `grep -E` | extended regex (`\|` 같은 alternation 을 이스케이프 없이 쓰기 위함) |
| `grep -i` | case-insensitive (sshd -T 출력은 소문자) |
| `^port\|^permitrootlogin` | "행 시작이 port 거나 permitrootlogin" |

### 2.8 `ss -tulnp | grep -E 'sshd|:20022'`

```bash
ss -tulnp | grep -E 'sshd|:20022'
```

**의미**: 현재 LISTEN 중인 모든 TCP/UDP 소켓을 나열하고, sshd 또는 20022 포트가 있는 라인만 보여줌.

**왜**: §2.7 은 "sshd 가 어떻게 설정되어 있나" 였다. 이 명령은 **"실제로 그 포트가 LISTEN 상태인가"** 를 OS 의 소켓 테이블에서 직접 확인.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `ss` | `netstat` 의 후속 (iproute2). 더 빠르고 표현식 필터를 지원 |
| `-t` | TCP 소켓 |
| `-u` | UDP 소켓 |
| `-l` | LISTEN 상태만 (`-l` 없으면 ESTABLISHED 도 포함) |
| `-n` | 포트를 숫자로(DNS·`/etc/services` 조회 안 함). 빠름 |
| `-p` | 소켓을 점유한 프로세스(`users:(("sshd",pid=N,fd=M))`) 표시. `sudo` 필요 |

---

## 3. UFW 방화벽 ([IG §2](IMPLEMENTATION_GUIDE.md))

### 3.1 `sudo ufw allow 20022/tcp comment 'SSH (custom)'`

```bash
sudo ufw allow 20022/tcp comment 'SSH (custom)'
```

**의미**: 인바운드 TCP 20022 포트를 허용하는 규칙 추가. 코멘트는 "SSH (custom)".

**왜**: UFW 를 `enable` 하기 **전에** 미리 깔아둬야 한다. 안 그러면 enable 직후 22→20022 로 들어오는 SSH 가 차단되어 락아웃.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `allow` | 허용 규칙 (반대는 `deny`, `reject`) |
| `20022/tcp` | "포트/프로토콜" 단축 문법 (전체 형태는 `to any port 20022 proto tcp`) |
| `comment 'TEXT'` | 규칙에 메모. `ufw status verbose` 에서 보임 — 나중에 자기 자신과 미래 운영자가 룰 의도를 알 수 있게 |

### 3.2 `sudo ufw allow 15034/tcp comment 'agent-app'`

```bash
sudo ufw allow 15034/tcp comment 'agent-app'
```

**의미·왜**: §3.1 과 동일 — agent_app 이 LISTEN 하는 포트.

### 3.3 `sudo ufw default deny incoming`

```bash
sudo ufw default deny incoming
```

**의미**: 기본 인바운드 정책을 "deny" 로. 명시적으로 `allow` 되지 않은 모든 인바운드 차단.

**왜**: "기본 거부 + 명시적 허용" 의 보안 원칙. 새 포트가 실수로 열려도 자동으로 막힘. 이 정책이 없으면 모든 포트가 기본 열려있고, deny 룰로 막아야 하는 역방향이 되어 관리가 어렵다.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `default` | 기본 정책 변경 (개별 룰 아님) |
| `deny` | 차단. `reject` 와 달리 응답 안 함(stealth) |
| `incoming` | 들어오는 방향만 (다른 옵션: `outgoing`, `routed`) |

### 3.4 `sudo ufw default allow outgoing`

```bash
sudo ufw default allow outgoing
```

**의미**: 기본 아웃바운드 정책 "allow". 시스템이 외부로 나가는 모든 연결 허용.

**왜**: 아웃바운드까지 막으면 `apt update`, DNS, NTP 같은 정상 동작이 모두 깨진다. 일반적인 서버는 아웃바운드는 열어둔다(필요시 별도 화이트리스트).

### 3.5 `sudo ufw --force enable`

```bash
sudo ufw --force enable
```

**의미**: UFW 활성화. 부팅 시 자동 시작도 같이 등록.

**왜**: 위 §3.1~§3.4 로 룰을 충분히 깔아둔 뒤 실제로 켠다.

**플래그**:
- `--force` — "기존 SSH 연결이 끊길 수 있다. 정말 활성화?" 대화 프롬프트 스킵. 스크립트화에 필수.
- `enable` — 활성화 (반대는 `disable`)

### 3.6 `sudo ufw status verbose`

```bash
sudo ufw status verbose
```

**의미**: UFW 상태 + 모든 규칙 + 기본 정책 + 로깅 레벨 출력.

**왜**: 검증의 가장 중요한 한 줄. `Status: active`, `Default: deny (incoming), allow (outgoing)`, 그리고 정확히 의도한 룰만 보이는지 한 화면에서 확인.

**플래그**:
- `status` — 상태 + 룰 출력 (`enable`/`disable` 와 달리 변경 안 함)
- `verbose` — `Default:`, `Logging:`, `New profiles:` 같은 메타 정보도 포함. 그냥 `status` 면 룰 표만 나옴

---

## 4. 계정 / 그룹 생성 ([IG §3.1~§3.2](IMPLEMENTATION_GUIDE.md))

### 4.1 `sudo groupadd -f agent-common`

```bash
sudo groupadd -f agent-common
```

**의미**: `agent-common` 그룹 생성. 다음 사용 가능한 gid 자동 할당.

**플래그**:
- `-f` — **force**. 이미 같은 이름의 그룹이 존재해도 에러 없이 종료 (idempotent). 스크립트를 두 번 돌려도 깨지지 않게.

> `-g GID` 로 특정 gid 지정도 가능 (시스템 전반에서 그룹 번호 표준화하고 싶을 때).

### 4.2 `sudo groupadd -f agent-core`

§4.1 과 동일. 별도 그룹.

### 4.3 `sudo useradd -m -s /bin/bash -G agent-common,agent-core agent-admin`

```bash
sudo useradd -m -s /bin/bash -G agent-common,agent-core agent-admin
```

**의미**: `agent-admin` 사용자 생성. 홈 디렉토리 만들고, 기본 셸은 bash, 보조 그룹은 agent-common 과 agent-core.

**왜**: 미션 §4.2 의 계정·그룹 매핑 그대로 — 운영(admin) 은 협업 + 민감자원 둘 다 접근.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `-m` | `--create-home` — `/home/agent-admin` 디렉토리 생성 + `/etc/skel` 의 기본 파일들 복사. 없으면 홈 디렉토리 안 만들어짐 → `sudo -iu agent-admin` 이 실패 |
| `-s SHELL` | 기본 셸 지정. `/bin/bash` 가 표준 |
| `-G g1,g2` | **보조 그룹** 콤마 구분 리스트. 1차(기본) 그룹은 자동으로 동명 그룹(`agent-admin`) 생성됨. 보조 그룹은 권한을 위해 추가로 속하는 그룹 |
| 인자 | 사용자 이름 (마지막 위치 인자) |

> `-G` 와 `-g` 의 차이가 핵심. `-g GROUP` 은 **1차 그룹** 을 지정 (기본은 동명 그룹). 보조 그룹은 무조건 `-G`. 둘을 헷갈리면 권한 정책이 깨진다.

### 4.4 `sudo useradd -m -s /bin/bash -G agent-common,agent-core agent-dev`

§4.3 과 동일 패턴, 다른 사용자. 마찬가지로 admin/dev 가 동시 멤버.

### 4.5 `sudo useradd -m -s /bin/bash -G agent-common agent-test`

```bash
sudo useradd -m -s /bin/bash -G agent-common agent-test
```

**의미**: agent-test 사용자. 보조 그룹은 agent-common **만**.

**왜**: QA 역할은 협업 영역(`upload_files`) 에만 접근, 민감자원(`api_keys`, log) 접근 불가. agent-core 에 안 넣는 것이 그 분리의 핵심.

---

## 5. 디렉토리 + 권한 + ACL ([IG §3.3~§3.4](IMPLEMENTATION_GUIDE.md))

### 5.1 `sudo -u agent-admin mkdir -p /home/agent-admin/agent-app/{bin,upload_files,api_keys}`

```bash
sudo -u agent-admin mkdir -p /home/agent-admin/agent-app/{bin,upload_files,api_keys}
```

**의미**: agent-admin 권한으로 `/home/agent-admin/agent-app` 와 그 아래 `bin`, `upload_files`, `api_keys` 디렉토리 일괄 생성.

**왜**: `sudo -u agent-admin` 으로 만들면 디렉토리의 소유자가 자동으로 agent-admin 이 된다. root 가 만든 다음 `chown` 하는 것보다 한 단계 적음. 또 brace expansion `{a,b,c}` 으로 한 명령에 3개 디렉토리.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `sudo -u USER` | [§0.2](#02-) (b) 모드 — USER 권한으로 실행 |
| `mkdir -p` | parents — 중간 디렉토리도 함께 생성. 이미 존재해도 에러 안 냄(idempotent) |
| `{a,b,c}` | **brace expansion** — bash 가 셸 단계에서 `path/a path/b path/c` 세 단어로 펼침 |

### 5.2 `sudo mkdir -p /var/log/agent-app`

```bash
sudo mkdir -p /var/log/agent-app
```

**의미**: 시스템 로그 디렉토리 생성.

**왜**: `/var/log/` 는 root 소유. agent-admin 으로 만들 수 없으므로 root 로 만든 뒤 §5.7 에서 그룹·모드·ACL 을 조정.

### 5.3 `sudo chown agent-admin:agent-common /home/agent-admin/agent-app/upload_files`

```bash
sudo chown agent-admin:agent-common /home/agent-admin/agent-app/upload_files
```

**의미**: upload_files 디렉토리의 소유자를 agent-admin, 그룹을 agent-common 으로 변경.

**왜**: agent-common 그룹 멤버(admin/dev/test) 가 협업할 수 있게 그룹 권한을 부여하기 위함. 다음 단계 chmod 2770 과 짝.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `chown USER:GROUP TARGET` | 소유자/그룹 동시 변경. `USER` 만 쓰면 소유자만, `:GROUP` 만 쓰면 그룹만 |
| `-R` (안 씀) | 하위 재귀. 디렉토리 한 개만 바꿀 때는 필요 없음 |

### 5.4 `sudo chmod 2770 /home/agent-admin/agent-app/upload_files`

```bash
sudo chmod 2770 /home/agent-admin/agent-app/upload_files
```

**의미**: upload_files 의 모드를 8진수 `2770` 으로 설정.

**왜**: 그룹 멤버(`agent-common`) 가 R/W/X 가능, 다른 사용자는 접근 불가, **setgid** 비트로 안에 만들어지는 파일이 부모 디렉토리의 그룹(agent-common) 상속.

**4자리 8진수 모드 분해**:

| 자리 | 값 | 의미 |
|---|---|---|
| 1번째 (특수) | `2` | setgid 비트만 켬 (4=setuid, 2=setgid, 1=sticky 의 OR 합) |
| 2번째 (owner) | `7` | rwx |
| 3번째 (group) | `7` | rwx |
| 4번째 (other) | `0` | --- |

> 흔히 보는 `chmod 755` 처럼 3자리만 주면 특수 비트는 0(없음). 4자리로 주는 것이 특수 비트 명시.

> `-R` 로 하위까지 적용할 수 있지만, default ACL 과 함께 쓰면 의도치 않은 권한이 손자 디렉토리로 퍼질 수 있어 주의.

### 5.5 `sudo setfacl -d -m g:agent-common:rwx /home/agent-admin/agent-app/upload_files`

```bash
sudo setfacl -d -m g:agent-common:rwx /home/agent-admin/agent-app/upload_files
```

**의미**: upload_files 디렉토리의 **default ACL** 에 "agent-common 그룹은 rwx" 규칙 추가.

**왜**: 이 디렉토리 안에 **새로 만들어지는 파일/하위 디렉토리** 가 자동으로 같은 ACL 을 상속받게 한다. 사람이 매번 신경 쓰지 않아도 협업 권한이 유지됨.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `setfacl` | ACL 설정 도구 (`acl` 패키지) |
| `-d` | **default** ACL 에 적용 (없으면 **access** ACL — 현재 디렉토리 자체의 권한) |
| `-m` | **modify** — 기존 ACL 에 항목 추가/변경. 반대는 `-x` (remove), `-b` (clear all) |
| `g:agent-common:rwx` | ACL 항목. 형식은 `[u|g|m|o]:[NAME]:[perms]` — u=user, g=group, m=mask, o=other |

> default ACL 은 **새 파일** 에만 영향. 이미 존재하는 파일에는 적용되지 않는다. 그래서 setfacl 은 디렉토리 생성 직후에 거는 게 가장 깔끔.

### 5.6 `sudo chown agent-admin:agent-core .../api_keys` + chmod 2770 + setfacl ...

```bash
sudo chown agent-admin:agent-core /home/agent-admin/agent-app/api_keys
sudo chmod 2770                   /home/agent-admin/agent-app/api_keys
sudo setfacl -d -m g:agent-core:rwx /home/agent-admin/agent-app/api_keys
```

**의미**: §5.3~§5.5 와 동일 패턴, 그룹만 `agent-core`.

**왜**: api_keys 는 민감 자원 — agent-core 멤버(admin, dev) 만 접근 가능해야 함. agent-test 는 agent-core 가 아니므로 자동으로 차단.

### 5.7 `sudo chown root:agent-core /var/log/agent-app` + chmod + setfacl

```bash
sudo chown root:agent-core   /var/log/agent-app
sudo chmod 2770              /var/log/agent-app
sudo setfacl -d -m g:agent-core:rwx /var/log/agent-app
```

**의미**: 시스템 로그 디렉토리. 소유자는 root(시스템 위치 컨벤션), 그룹은 agent-core 로 R/W 허용.

**왜**: monitor.sh 가 `agent-admin` (agent-core 멤버) 으로 실행될 때 sudo 없이 쓰기 가능해야 함. 그룹 멤버십이 곧 쓰기 권한.

### 5.8 `sudo chown agent-admin:agent-core .../bin` + chmod 2750

```bash
sudo chown agent-admin:agent-core /home/agent-admin/agent-app/bin
sudo chmod 2750                   /home/agent-admin/agent-app/bin
```

**의미**: bin 디렉토리. 모드만 `2750` 으로 다름.

**왜**: bin 안의 monitor.sh 는 그룹 멤버가 **실행** 만 하면 되고, 새 파일을 함부로 못 만들게 그룹의 쓰기 권한은 뺀다(`5` = r-x). default ACL 도 안 검 — 이 디렉토리 안에 새 파일이 만들어질 일이 거의 없음.

---

## 6. 계정/디렉토리 검증 ([IG §3.5](IMPLEMENTATION_GUIDE.md))

### 6.1 `id agent-admin`

```bash
id agent-admin
id agent-dev
id agent-test
```

**의미**: 지정 사용자의 uid, gid, 보조 그룹 목록 출력.

**왜**: §4 에서 등록한 사용자의 그룹 매핑이 정확한지 한 줄로 확인. `groups=...` 부분이 핵심.

**플래그 없음** (필요시 `-u`/`-g`/`-G` 로 부분만 출력 가능).

### 6.2 `ls -ld DIR`

```bash
ls -ld /home/agent-admin/agent-app /home/agent-admin/agent-app/* /var/log/agent-app
```

**의미**: 디렉토리 자체의 메타 정보(권한 비트, 소유자, 그룹, 크기, mtime, 이름) 한 줄 출력.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `-l` | long format. 권한 비트 + 링크 수 + 소유자/그룹 + 크기 + mtime |
| `-d` | **디렉토리** 를 디렉토리로 다루기 — 안 붙이면 ls 가 디렉토리의 **내용** 을 나열함. 디렉토리 자체 정보를 보려면 필수 |
| 와일드카드 `*` | bash 가 셸 단계에서 매치하는 모든 경로로 펼침 |

> 결과의 첫 컬럼이 `drwxrws---` 처럼 보일 때, `s` 는 setgid (`x` 자리에 표시). 대문자 `S` 면 `x` 가 없는 setgid (실행 불가하지만 setgid 켜진 비정상 상태).

### 6.3 `getfacl DIR`

```bash
getfacl /home/agent-admin/agent-app/upload_files
getfacl /home/agent-admin/agent-app/api_keys
getfacl /var/log/agent-app
```

**의미**: 지정 경로의 POSIX ACL 전체 덤프.

**왜**: §5.5 의 default ACL 이 실제로 박혀 있는지, mask 가 어떻게 잡혔는지 확인.

**출력 읽는 법**:
```
# file: home/agent-admin/agent-app/upload_files   ← 상대경로 (앞의 / 는 잘림)
# owner: agent-admin
# group: agent-common
# flags: -s-                                       ← s = setgid, t = sticky 등
user::rwx                                          ← 소유자 (= chmod 첫 자리)
group::rwx                                         ← 1차 그룹 (= chmod 두 번째 자리)
other::---                                         ← 기타 (= chmod 세 번째 자리)
default:user::rwx                                  ← 신규 파일에 적용될 기본값
default:group::rwx
default:group:agent-common:rwx                     ← 우리가 setfacl -d 로 넣은 라인
default:mask::rwx
default:other::---
```

`default:group:NAME:rwx` 가 들어 있으면 OK.

---

## 7. 환경 변수 + 키 파일 ([IG §4](IMPLEMENTATION_GUIDE.md))

### 7.1 `sudo tee /etc/profile.d/agent-app.sh >/dev/null <<'EOF' ... EOF`

```bash
sudo tee /etc/profile.d/agent-app.sh >/dev/null <<'EOF'
export AGENT_HOME="/home/agent-admin/agent-app"
export AGENT_PORT="15034"
export AGENT_UPLOAD_DIR="$AGENT_HOME/upload_files"
export AGENT_KEY_PATH="$AGENT_HOME/api_keys/t_secret.key"
export AGENT_LOG_DIR="/var/log/agent-app"
EOF
```

**의미**: heredoc 으로 여러 줄 텍스트를 sudo 권한의 tee 에 stdin 으로 보내고, tee 가 그걸 파일에 쓴다.

**왜**: root 소유 경로(`/etc/profile.d/`) 에 멀티라인 파일을 한 번에 작성하는 표준 패턴. `sudo cat > FILE <<EOF` 라고 하면 셸 리다이렉션이 sudo 적용 전에 일어나 권한 부족으로 실패한다.

**구성 요소 분해**:
| 토큰 | 의미 |
|---|---|
| `tee FILE` | stdin 을 stdout + FILE 양쪽에 |
| `>/dev/null` | tee 의 stdout 을 버림 (콘솔 더럽히지 않게) |
| `<<'EOF'` | heredoc 시작. `'EOF'` 처럼 작은따옴표로 감싸면 내부의 `$VAR` 가 expand 되지 **않음** — 파일에 `$AGENT_HOME` 글자가 그대로 들어가도록. 만약 `<<EOF` 였다면 호출 셸이 `$AGENT_HOME` 을 미리 풀어버려 의도가 깨짐 |
| `EOF` | heredoc 종료 마커. 같은 단어가 행 시작에 나타날 때까지 |

> `/etc/profile.d/*.sh` 는 로그인 셸이 시작할 때 자동으로 source 된다. 그래서 모든 로그인 사용자(agent-admin 포함) 에게 환경 변수가 자동 노출.

### 7.2 `sudo chmod 644 /etc/profile.d/agent-app.sh`

```bash
sudo chmod 644 /etc/profile.d/agent-app.sh
```

**의미**: 모드 `644` — 소유자(root) rw, 그룹 r, 기타 r.

**왜**: `/etc/profile.d/*.sh` 는 모든 사용자가 source 할 수 있도록 **읽기 권한** 이 필요. 쓰기는 root 만. 실행 권한은 source 에는 불필요(직접 실행 안 함). 이게 시스템 설정 파일의 표준 권한.

**`644` 분해**:
- `6` = 4(read) + 2(write) — owner rw
- `4` = 4(read) — group r
- `4` = 4(read) — other r

### 7.3 `sudo -u agent-admin bash -lc '...'`

```bash
sudo -u agent-admin bash -lc '
    printf "agent_api_key_test\n" > "$AGENT_KEY_PATH"
    chmod 640 "$AGENT_KEY_PATH"
'
```

**의미**: agent-admin 권한으로 bash 를 **로그인 셸**로 띄워 안의 명령 실행.

**왜**: 일반 `sudo -u agent-admin CMD` 는 `/etc/profile.d/` 를 source 하지 않아 `$AGENT_KEY_PATH` 가 비어 있다. `-l` 로 로그인 셸이 되면 source 가 일어나 환경 변수가 들어옴.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `-u USER` | sudo: USER 권한으로 |
| `bash -l` | **login shell** 로 시작 — `/etc/profile`, `/etc/profile.d/*.sh`, `~/.bash_profile` 등을 source |
| `bash -c CMD` | CMD 문자열을 실행하고 종료 |
| `-lc` | 둘을 합침 |
| `' ... '` | 외부 따옴표. 안쪽 `$AGENT_KEY_PATH` 는 expansion 안 되고 bash 에게 글자 그대로 전달 → bash 가 자기 환경에서 다시 expand |

### 7.4 `printf "agent_api_key_test\n" > "$AGENT_KEY_PATH"`

```bash
printf "agent_api_key_test\n" > "$AGENT_KEY_PATH"
```

**의미**: `agent_api_key_test` 와 줄바꿈 1개를 파일에 기록 (덮어쓰기).

**왜 `printf` 대신 `echo`?** — `echo` 는 셸/플랫폼마다 동작이 다르다(`-n` 옵션 등). `printf` 는 POSIX 표준이고 escape 시퀀스 처리가 명확해 스크립트에서 더 안전.

**구성 요소**:
| 토큰 | 의미 |
|---|---|
| `printf FMT` | C 의 printf 와 같은 포맷 문자열 처리 |
| `\n` | 줄바꿈 (newline) |
| `> FILE` | stdout 을 FILE 로 덮어쓰기 |
| `"$AGENT_KEY_PATH"` | 큰따옴표로 감싸 expand. 경로에 공백이 있어도 안전 |

### 7.5 `chmod 640 "$AGENT_KEY_PATH"`

```bash
chmod 640 "$AGENT_KEY_PATH"
```

**의미**: 키 파일 권한 `640` — owner rw, group r, other none.

**왜**: 키 파일은 그룹(agent-core) 멤버는 읽기만, owner(agent-admin) 만 쓰기 가능, 그 외에는 보이지도 않게.

**`640` 분해**:
- `6` = rw
- `4` = r
- `0` = ---

### 7.6 `sudo -iu agent-admin env | grep '^AGENT_'`

```bash
sudo -iu agent-admin env | grep '^AGENT_'
```

**의미**: agent-admin 으로 **완전히 새로 로그인한 셸** 의 환경 변수 중 `AGENT_` 로 시작하는 것만 출력.

**왜**: §7.1 의 profile.d 파일이 진짜로 시스템 전역에서 로딩되는지 가장 확실한 검증. 검증의 핵심은 "agent-admin 으로 새 로그인했을 때 5개 변수가 모두 보이는가".

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `sudo -i` | **initial login** — 진짜 로그인처럼 환경 초기화. `~/USER` 로 cd 까지 |
| `sudo -iu USER` | USER 의 로그인 셸로 |
| `env` | 현재 환경 변수 전체 출력 |
| `\| grep '^AGENT_'` | 환경 변수 중 `AGENT_` prefix 만 |

> `-i` 없는 `-u USER` 와의 가장 큰 차이: `-i` 는 `/etc/profile.d/*.sh` 를 source 한다. 없으면 환경 변수가 안 들어옴.

### 7.7 `sudo -u agent-admin cat /home/agent-admin/agent-app/api_keys/t_secret.key`

```bash
sudo -u agent-admin cat /home/agent-admin/agent-app/api_keys/t_secret.key
```

**의미**: agent-admin 권한으로 키 파일 내용 출력.

**왜**: 권한이 막혀서가 아니라 (a) 파일이 실제로 거기 있는가 (b) 내용이 정확히 `agent_api_key_test` 인가 둘 다 동시 검증.

### 7.8 `ls -l /home/agent-admin/agent-app/api_keys/t_secret.key`

```bash
ls -l /home/agent-admin/agent-app/api_keys/t_secret.key
```

**의미**: 파일의 권한·소유자·그룹·크기 한 줄 표시.

**왜**: 모드가 정말 `-rw-r-----`(=640) 이고 그룹이 `agent-core` 인지 확인. `agent-core` 그룹은 §5.6 의 setgid 덕에 자동 상속 — 그게 정말 일어났는지 본 명령으로 검증.

**플래그**:
- `-l` long format. `-d` 가 빠진 이유는 파일이라서 (디렉토리가 아니므로 `-d` 불필요)

---

## 8. 앱 배포 + 실행 ([IG §5](IMPLEMENTATION_GUIDE.md))

### 8.1 `sudo install -o agent-admin -g agent-core -m 0750 SRC DST`

```bash
sudo install -o agent-admin -g agent-core -m 0750 \
    ~/Codyssey/B1-1/agent-app/agent-app-linux-x86 \
    /home/agent-admin/agent-app/agent_app
```

**의미**: SRC 를 DST 로 복사하면서 **소유자/그룹/모드를 한 번에 설정**. 결과 파일은 `agent-admin:agent-core` 소유의 `0750` 모드.

**왜 `cp` 가 아니라 `install`?** — `cp` 로 복사하면 원본의 권한·소유자가 그대로 따라온다. 그러면 `chmod` + `chown` 을 다시 해야 함. `install` 은 그걸 한 명령에 처리하고, 디렉토리가 없으면 만들어주기까지 한다.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `install` | 빌드 시스템에서 자주 쓰이는 "복사 + 권한 설정" 도구 (coreutils) |
| `-o USER` | **owner** 지정 |
| `-g GROUP` | **group** 지정 |
| `-m MODE` | **mode** (8진수) 지정. `0750` 의 앞 `0` 은 특수비트 없음 명시 |
| `-D` (안 씀) | 대상 디렉토리가 없으면 만듦 |
| `-d` (안 씀) | 디렉토리만 생성 (`mkdir -p` 의 install 버전) |

### 8.2 `sudo -iu agent-admin -- bash -lc '"$AGENT_HOME/agent_app"'`

```bash
sudo -iu agent-admin -- bash -lc '"$AGENT_HOME/agent_app"'
```

**의미**: agent-admin 의 로그인 셸로 들어가 `$AGENT_HOME/agent_app` (포어그라운드) 실행.

**왜**: 미션 §4.3 의 "일반 계정으로 실행(루트 금지)" 요건. `-i` 로 로그인 환경을 보장해야 `$AGENT_HOME` 이 풀린다.

**플래그·문법 분해**:
| 토큰 | 의미 |
|---|---|
| `sudo -iu agent-admin` | agent-admin 의 로그인 셸로 (§7.6 와 같음) |
| `--` | sudo 의 옵션 끝 표식. 이후 토큰은 모두 명령으로 전달. agent_app 의 인자가 `-` 로 시작해도 sudo 옵션으로 오해 안 함 |
| `bash -lc` | login shell + command (§7.3 와 같음) |
| `'"$AGENT_HOME/agent_app"'` | 외부 따옴표 `'...'` 안에 내부 따옴표 `"..."` 가 들어감. 외부는 expand 차단, 내부는 안에서 bash 가 expand. 이중 따옴표가 필요한 이유: 경로에 공백이 있을 때(여기는 없지만 안전 패턴) |

### 8.3 `ss -tulnp | grep ':15034'`

```bash
ss -tulnp | grep ':15034'
```

**의미**: §2.8 과 동일한 ss. 15034 포트가 LISTEN 인지 확인.

**왜**: agent_app 의 Boot Sequence `[4/5] Port Availability [OK]` 만으로는 부족 — 그건 시작 *전* 가용성 검사. 진짜로 binding 했는지는 ss 로만 확인 가능.

---

## 9. monitor.sh 배포 + 실행 ([IG §6](IMPLEMENTATION_GUIDE.md))

### 9.1 `sudo install -o agent-dev -g agent-core -m 0750 SRC DST`

```bash
sudo install -o agent-dev -g agent-core -m 0750 \
    ~/Codyssey/B1-1/scripts/monitor.sh \
    /home/agent-admin/agent-app/bin/monitor.sh
```

**의미·플래그**: §8.1 과 같은 `install`. 차이는 owner 가 `agent-dev` 라는 점.

**왜 agent-dev 가 소유자?** — 미션 §4.4 의 권한 정책: "monitor.sh 작성자는 agent-dev". 작성자가 소유하고, agent-core 그룹이 실행 가능.

### 9.2 `sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh`

```bash
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh
```

**의미**: agent-admin 권한으로 monitor.sh 한 번 실행.

**왜 `-iu` 가 아니라 `-u`?** — monitor.sh 가 **자기 안에서** `/etc/profile.d/agent-app.sh` 를 source 하기 때문 ([scripts/monitor.sh:10-13](../scripts/monitor.sh#L10-L13)). 로그인 셸이 아니어도 환경 변수가 들어옴. cron 환경을 모사하는 의미도 있다 — cron 은 항상 비로그인.

### 9.3 `tail -n 5 /var/log/agent-app/monitor.log`

```bash
tail -n 5 /var/log/agent-app/monitor.log
```

**의미**: 로그 파일의 **마지막 5줄** 만 출력.

**왜**: 로그가 길어도 가장 최근 기록만 보면 되는 경우가 대부분. tail 의 진가는 `-f` (follow) 옵션이지만 본 검증에서는 정적 snapshot 만 필요.

**플래그 분해**:
| 토큰 | 의미 |
|---|---|
| `tail` | 파일 끝부터 |
| `-n N` | **N 줄**. (`-5` 처럼 줄여 쓸 수도 있지만 가독성 떨어짐) |
| `-f` (안 씀) | **follow** — 새 라인이 추가될 때마다 실시간 출력. `tail -f` 가 운영 디버깅의 일상 |
| `-F` (안 씀) | `-f` + 파일이 회전돼 새로 생긴 동명 파일도 따라감. logrotate 와 함께 유용 |

---

## 10. cron 등록 ([IG §7](IMPLEMENTATION_GUIDE.md))

### 10.1 `groups agent-admin | tr ' ' '\n' | grep -x agent-core`

```bash
groups agent-admin | tr ' ' '\n' | grep -x agent-core
```

**의미**: agent-admin 의 모든 그룹 목록에서 정확히 `agent-core` 인 줄이 있는지 확인.

**왜**: cron 으로 monitor.sh 를 실행하려면 agent-admin 이 `agent-core` 그룹 멤버여야(파일 실행 권한·로그 쓰기 권한) 한다. 사전 검증.

**플래그·구성 분해**:
| 토큰 | 의미 |
|---|---|
| `groups USER` | USER 의 그룹 멤버십을 공백 구분 한 줄로 출력 |
| `tr ' ' '\n'` | **translate** — 공백을 줄바꿈으로 치환. 공백 구분 → 줄 단위 |
| `grep -x PATTERN` | **eXact match** — 행 전체가 PATTERN 과 정확히 일치할 때만 매치. `agent-core-bonus` 같은 헷갈리는 부분 일치 방지 |

### 10.2 `sudo -u agent-admin bash -c '( crontab -l 2>/dev/null \| grep -v "monitor.sh" ; echo "* * * * * ..." ) \| crontab -'`

```bash
sudo -u agent-admin bash -c '
    ( crontab -l 2>/dev/null | grep -v "monitor.sh" ; \
      echo "* * * * * /home/agent-admin/agent-app/bin/monitor.sh >> /tmp/monitor.cron.log 2>&1" \
    ) | crontab -
'
```

**의미**: agent-admin 의 기존 crontab 에서 monitor.sh 라인은 빼고, 새 라인 1개를 추가한 결과를 통째로 새 crontab 으로 설치.

**왜 이렇게 복잡?** — 멱등성. 두 번 실행해도 monitor.sh 라인이 1개만 남도록. 기존 crontab 의 다른 라인은 보존.

**구성 분해**:
| 토큰 | 의미 |
|---|---|
| `sudo -u agent-admin bash -c '...'` | agent-admin 권한의 bash 에서 안쪽 명령 실행 |
| `( CMD1 ; CMD2 )` | **서브셸**. 두 명령의 stdout 을 한 묶음으로 모음 |
| `crontab -l 2>/dev/null` | 현재 crontab 출력 (없으면 stderr 에 에러 — `/dev/null` 로 버림) |
| `\| grep -v "monitor.sh"` | **-v** = invert. monitor.sh 가 들어간 행 **제외** |
| `; echo "* * * * * ..."` | 새로 추가할 1줄 |
| `\| crontab -` | stdin(`-`) 으로부터 새 crontab 을 받아 **통째로 설치**. crontab 은 stdin 으로 받으면 원자적으로 교체 |

**cron 시간 표현 `* * * * *`**:
| 자리 | 의미 |
|---|---|
| 1번째 | 분 (0-59) |
| 2번째 | 시 (0-23) |
| 3번째 | 일 (1-31) |
| 4번째 | 월 (1-12) |
| 5번째 | 요일 (0-7, 0과 7이 일요일) |

전부 `*` = "모든 값" — 즉 매분 매시 매일 매월 매요일 → **매분**.

**`>> /tmp/monitor.cron.log 2>&1`**:
- `>>` append (덮어쓰지 말고 누적)
- `2>&1` stderr 를 stdout 이 가는 곳으로 — 둘 다 파일에 누적

### 10.3 `sudo -u agent-admin crontab -l`

```bash
sudo -u agent-admin crontab -l
```

**의미**: agent-admin 의 현재 crontab 목록 출력.

**플래그**:
- `-l` list. (`-e` = edit 인터랙티브, `-r` = remove 전부 삭제 — 위험)

### 10.4 `sleep 70`

```bash
sleep 70
```

**의미**: 70초 대기.

**왜**: cron 은 매분 :00 초에 발화. 등록 시각이 :30 초였다면 30초만 기다리면 되지만, 최악의 경우 :01 초에 등록했다면 거의 60초를 기다려야 한다. 70 초면 안전 마진 포함 한 번의 발화는 확실히 잡힌다.

### 10.5 `tail -n 3 /var/log/agent-app/monitor.log`

§9.3 과 동일. 최근 3줄로 cron 발화 확인.

### 10.6 `tail -n 20 /tmp/monitor.cron.log`

```bash
tail -n 20 /tmp/monitor.cron.log
```

**의미**: cron 의 stdout/stderr 캡처 파일에서 최근 20줄.

**왜**: monitor.log 가 안 늘어나면 두 가지 가능성 — (a) cron 자체가 안 도는가, (b) 도는데 monitor.sh 가 `exit 1` 로 끝나는가. `/tmp/monitor.cron.log` 가 (b) 의 단서를 준다 — `[FAIL]` 라인이 있거나 환경 변수 미설정 에러가 있으면 거기 보임.

---

## 11. 부록 — 자주 헷갈리는 짝

### 11.1 `chmod` 8진수 모드 표

각 자리는 3비트(rwx) 의 합이다.

| 8진수 | rwx | 의미 |
|---|---|---|
| `0` | `---` | 권한 없음 |
| `1` | `--x` | 실행만 |
| `2` | `-w-` | 쓰기만 (드묾) |
| `3` | `-wx` | 쓰기 + 실행 |
| `4` | `r--` | 읽기만 |
| `5` | `r-x` | 읽기 + 실행 |
| `6` | `rw-` | 읽기 + 쓰기 |
| `7` | `rwx` | 전부 |

자주 보는 조합:
- `644` 일반 파일 (소유자 rw, 그룹/기타 r)
- `755` 실행 파일/디렉토리 (소유자 rwx, 그룹/기타 rx)
- `600` 비밀 키 (소유자만 rw)
- `640` 그룹 공유 비밀 (소유자 rw, 그룹 r)
- `750` 그룹 실행 허용 (소유자 rwx, 그룹 rx)
- `770` 그룹 협업 (소유자 + 그룹 rwx)

### 11.2 특수 비트 (4자리 모드의 첫 자리)

| 값 | 이름 | 디렉토리에서의 의미 | 파일에서의 의미 |
|---|---|---|---|
| `4` | setuid | (의미 없음) | 실행 시 소유자 권한으로 실행. `/usr/bin/passwd` 가 대표 |
| `2` | setgid | **안에 만들어지는 파일/디렉토리는 부모의 그룹 상속** ← 이 미션 핵심 | 실행 시 그룹 권한으로 실행 |
| `1` | sticky | **소유자만 파일을 삭제할 수 있음** (`/tmp` 가 대표) | (의미 없음) |

값은 OR 합산. setgid + setuid = `4+2=6`, setgid + sticky = `2+1=3`, 등.

**이 미션에서 쓴 조합**:
- `2770` = setgid + rwxrwx--- → upload_files / api_keys / /var/log/agent-app
- `2750` = setgid + rwxr-x--- → bin
- `0750` = (특수비트 없음) + rwxr-x--- → 실행 가능한 monitor.sh, agent_app

### 11.3 ACL: access ACL vs default ACL

- **access ACL** — 그 파일/디렉토리 **자체** 의 권한 (전통적 mode 비트의 확장)
- **default ACL** — **디렉토리에만** 적용. 그 안에 **새로 만들어지는** 파일/디렉토리에 자동 상속됨

`setfacl -m ...` 는 access, `setfacl -d -m ...` 는 default.

`getfacl` 의 출력에서:
- `user::rwx` / `group::rwx` / `other::---` ← access ACL (mode 비트와 동기)
- `user:NAME:rwx` / `group:NAME:rwx` ← 추가 ACL 항목
- `mask::rwx` ← 그룹/사용자 항목의 effective 권한 상한
- `default:...` 라인 전부 ← default ACL

### 11.4 systemd: `.service` vs `.socket`

| Unit | 역할 |
|---|---|
| `.service` | 일반 서비스. 시작하면 LISTEN 까지 함께 |
| `.socket` | 포트만 LISTEN 하다가 연결이 오면 대응하는 `.service` 를 spawn (lazy start). `inetd` 의 systemd 버전 |

Ubuntu 22.04 의 `ssh.socket` 이 활성화되면 22 를 socket 이 잡고 연결 시 sshd 를 띄움. 우리가 `ssh.service` 의 Port 만 바꿔서는 socket 이 22 를 계속 잡고 있어 LISTEN 이 중복된다. 그래서 [§2.4](#24-sudo-systemctl-disable---now-sshsocket-2devnull--true) 의 `disable --now ssh.socket` 이 필요.

### 11.5 `sudo` 3가지 모드 비교

| 명령 | uid | 환경 변수 | cwd | 언제 |
|---|---|---|---|---|
| `sudo CMD` | 0 (root) | 일부 보존, `PATH` 는 secure_path | 그대로 | 시스템 변경 (apt, systemctl, mkdir 등) |
| `sudo -u USER CMD` | USER | 호출자 환경 일부 보존, `/etc/profile.d/*` 는 source **안 함** | 그대로 | USER 권한으로 빠른 단발 명령 (cron 환경 유사) |
| `sudo -iu USER CMD` | USER | 완전 초기화, `/etc/profile`, `~/.bash_profile` 등 모두 source | USER 의 홈 | 사용자가 진짜로 로그인한 것처럼 동작해야 할 때 |

이 미션에서:
- 시스템 셋업 (`apt`, `useradd`, `chmod`, ...) → 그냥 `sudo`
- monitor.sh 실행 / cron 등록 → `sudo -u agent-admin` (cron 환경 모사)
- 환경 변수 검증 / 앱 실행 / 키 파일 생성 → `sudo -iu agent-admin` (전역 env 확인)

---

> 본 문서는 IMPLEMENTATION_GUIDE 의 모든 명령을 한 번씩 풀어본 레퍼런스다. 처음 한 번은 처음부터 끝까지 정독하고, 이후로는 IG 의 § 번호를 기억해 두면 본 문서 §X 로 곧장 점프할 수 있다.
