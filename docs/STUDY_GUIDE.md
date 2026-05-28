# B1-1 최종 결과물 해설 — 학습자용 가이드

본 문서는 [MISSION.md](MISSION.md) 의 산출물·요구사항을 실제로 구현한 뒤, **학습자가 평가자에게 결과물과 그 설계 근거를 말로 풀어낼 수 있도록** 정리한 자습용 가이드다. [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) 가 "어떻게 했는지", [EXECUTION_REPORT.md](EXECUTION_REPORT.md) 가 "무엇을 했는지(증거)" 라면, 본 문서는 **"왜 그렇게 했고, 어떻게 설명할 것인지"** 를 담는다.

---

## 0. 이 문서의 사용법

- **발표 대본이 아니라 자기 테스트지**. §4 의 각 "핵심 답변" 을 외우지 말고, 그 아래 "구현 / 검증" 항을 보면서 자기 말로 다시 풀어 말해 본다. 30초 안에 막힘없이 말 나오면 통과.
- **모든 주장에는 출처가 있다**. 결과물·코드의 정확한 위치를 마크다운 링크로 달아두었다. 평가 자리에서 화면을 띄울 때 그 라인을 바로 짚을 수 있어야 한다.
- **잘 모르겠는 부분은 §6 FAQ 부터** 보면 자주 나오는 곁가지 질문이 정리되어 있다.

---

## 1. 한눈에 보는 최종 결과물

미션 [§2](MISSION.md) 는 산출물 2가지를 요구한다.

| # | 산출물 | 파일 경로 | 한 줄 설명 |
|---|---|---|---|
| ① | 요구사항 수행 내역서 | [docs/EXECUTION_REPORT.md](EXECUTION_REPORT.md) | 8개 필수 증거 자료를 명령/기대출력/실측출력의 4단 구조로 정리 |
| ② | 자동화 스크립트 소스 | [scripts/monitor.sh](../scripts/monitor.sh) | 시스템 상태 수집 + 임계값 경고 + 로그 회전을 수행하는 Bash 스크립트 |

### 1.1 8개 체크리스트 → EXECUTION_REPORT 위치 매핑

| # | 미션 [§2.1](MISSION.md) 체크리스트 | EXECUTION_REPORT 위치 | 핵심 증거 |
|---|---|---|---|
| ① | SSH 포트 20022 + Root 차단 | [§1.4](EXECUTION_REPORT.md#14-실제-실행-결과) | `sshd -T` 출력 2줄 + `ss` LISTEN 라인 |
| ② | UFW 활성 + 20022/15034 only | [§2.4](EXECUTION_REPORT.md#24-실제-실행-결과) | `ufw status verbose` 의 Default + 4개 ALLOW |
| ③ | 계정·그룹 생성 | [§3.4](EXECUTION_REPORT.md#34-실제-실행-결과) | `id` 3개 + `getent group` 2개 |
| ④ | 디렉토리 구조 + 권한 + ACL | [§4.4](EXECUTION_REPORT.md#44-실제-실행-결과) | `ls -ld` + `getfacl` 3개 |
| ⑤ | Boot Sequence 5/5 + READY | [§6.4](EXECUTION_REPORT.md#64-실제-실행-결과) | 5단계 [OK] 콘솔 + `ss :15034` |
| ⑥ | `monitor.sh` 실행 결과 | [§7.4](EXECUTION_REPORT.md#74-실제-실행-결과) | HEALTH OK + RESOURCE + WARNING |
| ⑦ | `monitor.log` 누적 | [§8.3](EXECUTION_REPORT.md#83-실제-실행-결과) | `tail -n 5` 미션 §8 포맷 |
| ⑧ | crontab 매분 자동 누적 | [§9.4](EXECUTION_REPORT.md#94-실제-실행-결과) | `crontab -l` + 1분 뒤 라인 수 증가 |

평가 자리에서 어느 항목을 묻든 위 표만 보면 EXECUTION_REPORT 의 해당 § 로 곧장 점프할 수 있다.

---

## 2. 산출물 ① — 요구사항 수행 내역서 해부

### 2.1 왜 4단 구조인가

[EXECUTION_REPORT.md](EXECUTION_REPORT.md) 의 모든 절은 동일한 4단을 따른다.

1. **수행 내용** — 1~2줄로 "이 절에서 무엇을 했나"
2. **수행 명령** — 그것을 만들어낸 실제 명령
3. **검증 명령 + 기대 출력** — 채점관이 직접 돌려볼 수 있는 명령과 통과 기준
4. **실제 실행 결과** — 위 검증 명령을 실제로 돌린 출력

이 구조의 장점은 **"명령 → 기대 → 실측"** 의 삼각 검증을 한 화면에 보여준다는 것이다. 채점관은 "실측이 기대를 만족하는가" 만 확인하면 된다.

### 2.2 각 절이 증명하는 미션 요구

| EXECUTION_REPORT § | 대응 미션 § | 증명하는 사실 |
|---|---|---|
| §1 SSH 보안 | [§4.1](MISSION.md) SSH 설정 | 포트 20022 + PermitRootLogin no 가 설정 파일·런타임 둘 다에 반영 |
| §2 방화벽 | [§4.1](MISSION.md) 방화벽 | UFW active + 정확히 20022/15034 만 ALLOW IN |
| §3 계정·그룹 | [§4.2](MISSION.md) 계정 표 | admin/dev 가 common+core, test 는 common only |
| §4 디렉토리·ACL | [§4.2](MISSION.md) 권한 표 | 그룹 소유 + setgid(2770) + default ACL 세 가지가 동시 성립 |
| §5 환경변수·키 | [§4.3](MISSION.md) | 전역 env + 키 파일이 일반 계정으로 읽힘 — Boot 통과의 전제 |
| §6 Boot Sequence | [§4.3](MISSION.md) | 5단계 [OK] + READY + 0.0.0.0:15034 LISTEN |
| §7 monitor.sh | [§4.4](MISSION.md) | Health/방화벽/리소스/임계값/로그 5요건 동시 충족 |
| §8 monitor.log | [§4.4](MISSION.md) 로그 포맷 | `[ts] PID:.. CPU:..% MEM:..% DISK_USED:..%` |
| §9 crontab | [§4.5](MISSION.md) | 등록 + 1분 후 자동 누적 (사람이 안 돌려도 늘어남) |

### 2.3 §5 가 "체크리스트 직접 항목" 이 아닌 이유

미션 [§2.1](MISSION.md) 의 8개 체크리스트는 환경 변수/키 파일을 별도 항목으로 세지 않는다. 하지만 ⑤(Boot Sequence) 가 `[2/5] Verifying Environment Variables` 와 `[3/5] Checking Required Files` 를 검사하므로 사전 조건으로 반드시 만족해야 한다. EXECUTION_REPORT 가 §5 를 따로 둔 것은 그 사전 조건 충족을 명시적으로 보여주기 위함이다.

---

## 3. 산출물 ② — `monitor.sh` 해부

### 3.1 전체 4단계

[scripts/monitor.sh](../scripts/monitor.sh) 는 다음 흐름이다.

1. **환경 변수 로드** — [scripts/monitor.sh:10-16](../scripts/monitor.sh#L10-L16): cron 환경은 `/etc/profile.d/*` 를 자동 source 하지 않으므로 명시적으로 끌어온다. 미설정 시 안전한 기본값(`AGENT_LOG_DIR`, `AGENT_PORT`) 으로 폴백.
2. **Health Check** — [scripts/monitor.sh:32-50](../scripts/monitor.sh#L32-L50): 프로세스/포트 확인, 실패 시 `exit 1` 로 즉시 종료.
3. **상태 점검** — [scripts/monitor.sh:56-60](../scripts/monitor.sh#L56-L60): UFW 비활성 시 `[WARNING]` 만 출력, **종료하지 않음**. 미션 [§4.4](MISSION.md) "방화벽: 경고만 출력" 요건을 그대로 반영.
4. **리소스 수집 + 임계값 경고 + 로그 기록** — [scripts/monitor.sh:134-171](../scripts/monitor.sh#L134-L171): CPU/MEM/DISK 를 측정해 콘솔에 출력, 임계 초과 시 경고, 마지막에 로그 파일로 1줄 append.

### 3.2 설계 결정 — 왜 그렇게 했는가

| 결정 | 이유 |
|---|---|
| `pgrep -f "${APP_NAME}"` ([:34](../scripts/monitor.sh#L34)) | 실행파일 이름이 아니라 명령행 전체로 매칭 — 절대경로 실행에도 잡힘. `head -n1` 로 첫 PID 만 취해 다중 인스턴스에서도 안전. |
| `ss -tln "sport = :${AGENT_PORT}"` ([:44](../scripts/monitor.sh#L44)) | `-l` LISTEN 만, `-n` 숫자 출력으로 빠름. 필터 표현식 `sport = :PORT` 를 ss 에게 위임해 grep 의존을 줄임. |
| `systemctl is-active --quiet ufw` ([:57](../scripts/monitor.sh#L57)) | sudo 없이 일반 계정도 호출 가능. `--quiet` 로 stdout 안 더럽힘. exit code 만 사용. |
| `/proc/stat` 1초 차분 ([:65-90](../scripts/monitor.sh#L65-L90)) | `top -b -n1` 처럼 외부 도구 의존 없이 CPU 누적값의 차로 사용률 계산 — 가벼움 + 결정적. |
| `/proc/meminfo` (MemTotal - MemAvailable) ([:92-97](../scripts/monitor.sh#L92-L97)) | `free` 의 used 컬럼은 버전마다 정의가 다름. `MemAvailable` 은 커널이 보장하는 "추가로 쓸 수 있는 RAM" 의 정확한 지표. |
| `df --output=pcent /` ([:99-101](../scripts/monitor.sh#L99-L101)) | 루트 파티션만, 사용률만 — `awk` 로 컬럼 자르는 것보다 안정적. |
| `awk` 실수 비교 ([:127-129](../scripts/monitor.sh#L127-L129)) | bash 의 `(( ))` 는 정수만 지원. CPU/MEM 은 소수점 1자리. awk 의 산술 비교로 우회. |
| 자체 회전 로직 ([:106-122](../scripts/monitor.sh#L106-L122)) | `logrotate` 추가 설치/설정 없이 스크립트 자체로 완결. 미션 [§4.4](MISSION.md) "방법 자유" 단서를 활용한 단순화. |

### 3.3 임계값과 회전 정책

| 항목 | 값 | 출처 |
|---|---|---|
| CPU > 20% → WARNING | [scripts/monitor.sh:23](../scripts/monitor.sh#L23) | 미션 [§4.4](MISSION.md) 임계값 표 |
| MEM > 10% → WARNING | [:24](../scripts/monitor.sh#L24) | 〃 |
| DISK > 80% → WARNING | [:25](../scripts/monitor.sh#L25) | 〃 |
| 회전 크기 | 10 MiB ([:20](../scripts/monitor.sh#L20)) | 미션 "최대 10MB" |
| 보관 파일 수 | 10개 (`.1` ~ `.10`) ([:21](../scripts/monitor.sh#L21)) | 미션 "10개 파일" |

> **주의**: 회전 정책은 활성 `monitor.log` + 백업 10개 = 최대 11개 파일을 둔다. "최대 10개" 를 엄격히 해석하면 백업을 `.1~.9` 로 줄여야 한다. 본 구현은 보수적/관대 해석을 택했다.

---

## 4. 미션 [§3](MISSION.md) — 6개 과제 목표에 대한 설명

이 절은 평가의 본문이다. 각 목표마다 (1) 30초 핵심 답변 → (2) 이번 미션에서의 구현 → (3) 증거 위치 의 3단으로 정리했다.

---

### 4.1 목표 1 — "SSH 포트 변경과 Root 원격 접속 차단이 왜 기본 보안에 해당하는지 설명할 수 있다"

**(1) 핵심 답변 (30초)**

22 포트는 인터넷의 자동 스캐너·brute-force 봇이 1순위로 두드리는 표적이다. 비표준 포트(20022) 로 옮기면 **자동화된 무차별 공격 시도가 대부분 걸러진다** — 보안이 강해서가 아니라, 노이즈가 줄어 진짜 위협에 집중할 수 있게 된다. Root 차단은 다른 축이다. 만약 누군가 비밀번호를 추측해 들어오더라도 **곧바로 시스템 전체 권한을 잡지 못한다** — 일반 계정으로 들어와 `sudo` 로 다시 한 번 권한 상승을 거쳐야 하므로 방어선이 한 겹 더 생긴다. 이 두 가지가 "기본" 인 이유는, 추가 비용 거의 없이 공격 표면을 크게 줄이는 1차 방어이기 때문이다.

**(2) 구현**

- [/etc/ssh/sshd_config](IMPLEMENTATION_GUIDE.md) 에 `Port 20022`, `PermitRootLogin no` 적용 — [IMPLEMENTATION_GUIDE.md §1.1](IMPLEMENTATION_GUIDE.md)
- `ssh.socket` 도 함께 비활성화 — Ubuntu 22.04 의 socket activation 이 22번을 별도 LISTEN 으로 열어 충돌을 일으킬 수 있어, 한 군데서만 LISTEN 하도록 정리

**(3) 증거**

[EXECUTION_REPORT §1.4](EXECUTION_REPORT.md#14-실제-실행-결과) — `sshd -T` 의 `port 20022` + `permitrootlogin no` 두 줄, `ss -tulnp` 의 LISTEN 라인.

---

### 4.2 목표 2 — "UFW 또는 firewalld 중 하나를 선택해 '필요 포트만 허용' 하는 방화벽 정책을 구성하고 검증할 수 있다"

**(1) 핵심 답변 (30초)**

방화벽 정책은 **"기본 거부 + 명시적 허용"** 으로 짜는 것이 원칙이다. UFW 를 활성화한 뒤 `default deny incoming` 으로 모든 인바운드를 막아두고, 운영에 꼭 필요한 두 포트만 — SSH(20022), 앱(15034) — 명시적으로 `allow` 했다. 이렇게 하면 새 포트가 실수로 열리는 일이 원천적으로 막히고, 룰 목록을 한 번 훑으면 "지금 인터넷에 공개된 게 무엇인가" 가 즉시 답 나온다. 검증은 `ufw status verbose` 한 줄이면 충분하다 — `Status: active`, `Default: deny (incoming)`, 그리고 정확히 두 포트(v4/v6 각각) 만 ALLOW IN 으로 나오는지 확인한다.

**(2) 구현**

- enable 전에 SSH/앱 포트 먼저 allow → 락아웃 방지 — [IMPLEMENTATION_GUIDE.md §2.1](IMPLEMENTATION_GUIDE.md)
- 기본 정책: `deny incoming` / `allow outgoing` — outbound 까지 막으면 apt/dns/ntp 가 깨짐
- `ufw --force enable` 의 `--force` 는 "정말 활성화하시겠습니까" 프롬프트 우회 — 스크립트화 가능

**(3) 증거**

[EXECUTION_REPORT §2.4](EXECUTION_REPORT.md#24-실제-실행-결과) — `Status: active`, `Default: deny (incoming)`, 4 라인 ALLOW (v4/v6 × 2 포트). 다른 인바운드 ALLOW 가 없음을 한 화면에서 확인 가능.

---

### 4.3 목표 3 — "역할 기반 계정/그룹과 ACL을 통해 '공유 디렉토리' 와 '보안 디렉토리' 를 분리하는 이유를 설명할 수 있다"

**(1) 핵심 답변 (30초)**

같은 시스템에서 일하는 사람들의 **역할은 다르다**. agent-admin/dev/test 세 역할 중 admin/dev 만 민감 자원(API 키, 로그) 에 접근하고, test 는 협업 영역(업로드) 에만 접근해야 한다. 이 분리를 사용자 단위로 일일이 `chown` 하면 인원이 늘어날 때마다 룰이 깨진다. 대신 **그룹** 으로 묶고(`agent-common` = 협업 3인, `agent-core` = 민감자원 2인), 디렉토리에는 그룹 권한만 주는 형태로 만들면 인원 변경이 그룹 멤버십 한 줄로 끝난다. ACL — 특히 default ACL — 은 그 안에서 새로 생성되는 파일도 같은 정책을 자동으로 상속시켜, 사람이 매번 신경 쓰지 않아도 정책이 유지된다. **공유(`upload_files`)** 는 agent-common 에 R/W, **보안(`api_keys`, `/var/log/agent-app`)** 은 agent-core 에 R/W ONLY 로 분리한 것이 그 결과다.

**(2) 구현**

- 디렉토리별 그룹 + setgid(2770) + default ACL — [IMPLEMENTATION_GUIDE.md §3.4](IMPLEMENTATION_GUIDE.md)
- setgid (`2770`) 의 `s` 비트는 "이 디렉토리 안에서 만들어지는 파일은 부모 디렉토리의 그룹을 상속" — 협업 시 그룹 일관성 보장
- default ACL (`setfacl -d -m g:GROUP:rwx`) 은 새 파일/하위 디렉토리에 자동 적용되는 ACL 청사진

**(3) 증거**

[EXECUTION_REPORT §3.4](EXECUTION_REPORT.md#34-실제-실행-결과) (계정·그룹) + [§4.4](EXECUTION_REPORT.md#44-실제-실행-결과) (`ls -ld` 의 `drwxrws---` + `getfacl` 의 `default:group:...:rwx` 라인).

---

### 4.4 목표 4 — "환경 변수(`AGENT_HOME` 등) 로 실행 환경을 고정하는 이유와 검증 방법을 설명할 수 있다"

**(1) 핵심 답변 (30초)**

앱이 동작하는 데 필요한 경로·포트·키 위치를 **코드에 하드코딩하면** 배포 환경이 바뀔 때마다 코드를 고쳐야 한다. 대신 환경 변수로 빼서 시스템 전역(`/etc/profile.d/agent-app.sh`) 에 정의해두면, 앱·monitor.sh·cron 등 어떤 실행 경로에서든 **같은 값을 보장**받는다. 특히 cron 환경은 PATH·환경 변수가 극단적으로 빈약하므로, monitor.sh 가 자기 안에서 다시 한 번 `source /etc/profile.d/agent-app.sh` 를 호출해 cron 으로부터의 호출도 동일 환경에서 돈다. 검증은 `sudo -iu agent-admin env | grep '^AGENT_'` — 로그인 셸 초기화 후 5개 변수가 모두 보이면 통과.

**(2) 구현**

- `/etc/profile.d/agent-app.sh` — [IMPLEMENTATION_GUIDE.md §4.1](IMPLEMENTATION_GUIDE.md): `AGENT_HOME / PORT / UPLOAD_DIR / KEY_PATH / LOG_DIR` 5개
- monitor.sh 내부 source — [scripts/monitor.sh:10-13](../scripts/monitor.sh#L10-L13): cron 의 빈약한 환경에도 같은 변수가 보장됨
- 키 파일은 `$AGENT_KEY_PATH/secret.key` (자세한 사정은 §5 참조)

**(3) 증거**

[EXECUTION_REPORT §5.4](EXECUTION_REPORT.md#54-실제-실행-결과) — `env | grep ^AGENT_` 의 5줄 출력 + 키 파일 내용 1줄 + `ls -l` 의 소유/모드.

---

### 4.5 목표 5 — "쉘 스크립트로 프로세스/포트/리소스 상태를 수집하고, 로그로 남겨 운영 문제를 추적하는 흐름을 설명할 수 있다"

**(1) 핵심 답변 (30초)**

운영 문제는 발생한 *후에* 원인을 추적해야 하는 경우가 대부분이다. 그래서 **상태를 평시에 꾸준히 기록**해 두는 것이 핵심이다. monitor.sh 는 매 실행마다 (a) 프로세스가 살아있는지, (b) 포트가 LISTEN 하는지 — 이 두 가지가 실패하면 즉시 `exit 1` 로 알람 — 를 본 다음, (c) CPU/MEM/DISK 를 측정해 임계 초과 시 경고만 띄우고 (스크립트는 계속 동작), (d) 결과를 표준 포맷 `[ts] PID:.. CPU:..% MEM:..% DISK_USED:..%` 한 줄로 `/var/log/agent-app/monitor.log` 에 append 한다. 이 한 줄 포맷이 중요한 이유는 **사후에 grep·awk·sort 로 시계열 분석**이 가능하기 때문이다. 장애가 발생하면 그 시각 전후 라인을 보면 CPU 가 언제부터 튀었는지가 즉시 드러난다.

**(2) 구현**

- Health Check (실패 시 종료) — [scripts/monitor.sh:32-50](../scripts/monitor.sh#L32-L50)
- 방화벽 점검 (경고만) — [scripts/monitor.sh:56-60](../scripts/monitor.sh#L56-L60)
- 자원 수집 — [scripts/monitor.sh:65-101](../scripts/monitor.sh#L65-L101): /proc/stat 차분, /proc/meminfo 비율, df pcent
- 임계값 경고 — [scripts/monitor.sh:154-162](../scripts/monitor.sh#L154-L162)
- 로그 append — [scripts/monitor.sh:165-167](../scripts/monitor.sh#L165-L167)

**(3) 증거**

[EXECUTION_REPORT §7.4](EXECUTION_REPORT.md#74-실제-실행-결과) (콘솔 출력) + [§8.3](EXECUTION_REPORT.md#83-실제-실행-결과) (로그 라인 포맷).

---

### 4.6 목표 6 — "crontab으로 모니터링을 주기 실행시키고, 로그 보존 정책(압축/삭제) 이 왜 필요한지 설명할 수 있다"

**(1) 핵심 답변 (30초)**

사람이 매분 `monitor.sh` 를 손으로 돌릴 수는 없다. **시계열 데이터는 누락 없는 자동 수집이 본질**이고, 그래서 `agent-admin` 의 crontab 에 `* * * * *` 라인을 등록해 매분 자동 실행하게 했다. 다만 로그는 자동으로 쌓이는 만큼 빠르게 디스크를 잠식한다 — 1주만 지나도 만 줄이 넘는다. 그래서 보존 정책이 필수다: (a) **회전** 으로 최근 N개 파일만 유지, (b) **압축** 으로 자주 안 보는 오래된 로그의 공간을 90% 이상 절약, (c) **삭제** 로 가치보다 보관 비용이 큰 아주 오래된 로그를 정리. 이번 미션의 필수 범위는 (a) 회전(10MB/10파일) 까지이고, monitor.sh 내부에서 직접 구현했다. (b), (c) 는 보너스 [§5.2](MISSION.md) 의 영역.

**(2) 구현**

- cron 등록 — [IMPLEMENTATION_GUIDE.md §7.2](IMPLEMENTATION_GUIDE.md): `agent-admin` 의 crontab 에 매분 라인
- stdout/stderr 를 `/tmp/monitor.cron.log` 로 캡처 — cron 자체가 동작하는지 디버깅 용이
- monitor.sh 의 회전 — [scripts/monitor.sh:106-122](../scripts/monitor.sh#L106-L122): 10MB 초과 시 `.1~.10` 시프트, 11번째부터 삭제

**(3) 증거**

[EXECUTION_REPORT §9.4](EXECUTION_REPORT.md#94-실제-실행-결과) — `crontab -l` 한 줄 + 70초 대기 전후 `wc -l` 비교(3→4) + `tail -n 3` 의 마지막 라인이 cron 발화 시각(`02:54:02`).

---

## 5. 작업 중 발견된 이슈와 대응 (정직 코너)

평가 자리에서 "혹시 어려운 점은 없었나요?" 가 나오면, 다음 두 가지를 짚으면 된다. 둘 다 **발견 → 진단 → 최소 침습 수정** 의 과정을 보여주는 좋은 예다.

### 5.1 `AGENT_KEY_PATH` 표기와 바이너리 동작의 불일치

- **현상**: Boot Sequence `[2/5] Verifying Environment Variables [FAIL]` 메시지가 `Key Path Mismatch. Expected: /home/agent-admin/agent-app/api_keys`. 즉 바이너리는 `AGENT_KEY_PATH` 를 **디렉토리** 로 기대.
- **문서 표기**: [MISSION.md §4.3](MISSION.md) 표는 `AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key` 라고 함 (파일 경로).
- **해결**: 바이너리가 실제로 어떻게 동작하는지에 맞춰 `AGENT_KEY_PATH=$AGENT_HOME/api_keys` 로 변경. 키 파일명도 바이너리가 요구하는 `secret.key` 로 변경. [EXECUTION_REPORT §5.1](EXECUTION_REPORT.md#51-수행-내용) 에 비고로 명시.
- **교훈**: 문서와 실제 동작이 어긋날 때는 **실제 동작이 진실**이며, 그 사실 자체를 문서화한다.

### 5.2 `monitor.sh` /proc/stat CPU 파싱 버그

- **현상**: monitor.sh 첫 실행 시 `CPU Usage : %` (값 누락) + `line 80: 0 0 0: syntax error in expression` 에러.
- **진단**: `/proc/stat` 의 `cpu` 라인은 커널 ≥ 2.6.33 에서 8개 필드(user~steal) 외에 추가 2개(guest, guest_nice) 를 갖는다. 기존 `read -r _ u1 ... st1` 은 8개 변수만 받아 마지막 변수 `st1` 에 `"0 0 0"` (잔여 3필드의 공백 결합) 이 들어가, 산술 표현식 평가 시 깨짐.
- **수정**: [scripts/monitor.sh:73-76](../scripts/monitor.sh#L73-L76) 에 `_rest1`/`_rest2` 변수를 추가해 잔여 필드를 흡수. 1줄 수정으로 호환성 확보.
- **교훈**: 시스템 인터페이스(`/proc/*`) 는 커널 버전에 따라 필드가 늘 수 있다. 정해진 개수만 받지 말고 **잔여를 흡수할 변수** 를 두는 것이 안전하다.

---

## 6. 예상 후속 질문 (FAQ)

평가 자리에서 자연스럽게 나올 만한 곁가지 질문들. 각자 1~2문장으로 답 가능해야 한다.

### Q1. ACL 까지 쓴 이유? `chown/chmod` 만으로 부족한가요?

`chown/chmod` 만으로는 "그 디렉토리 안에서 *새로* 만들어지는 파일에 어떤 권한이 적용될지" 를 정할 수 없다. setgid 비트는 그룹 상속까지는 처리하지만 모드까지는 못 제어한다. default ACL 은 "이 디렉토리에서 만들어지는 파일에는 자동으로 다음 권한을 부여하라" 는 청사진이라, 협업 환경에서 사람이 매번 신경 쓰지 않아도 정책이 유지된다.

### Q2. 왜 `2770`(setgid) 인가요? `0770` 과 차이는?

앞자리 `2` 가 **setgid 비트**. `2770` 디렉토리 안에 파일을 만들면 만든 사람의 기본 그룹이 아니라 **부모 디렉토리의 그룹**을 상속한다. 예: agent-admin 이 `/home/agent-admin/agent-app/api_keys` (그룹 agent-core) 안에 `secret.key` 를 만들면, 자동으로 그룹이 agent-core 로 잡힌다 — agent-dev 도 읽을 수 있게 된다. `0770` 이라면 만든 사람의 기본 그룹(agent-admin) 이 적용돼 협업이 깨진다.

### Q3. cron 환경의 PATH/환경변수 문제는 어떻게 해결했나요?

두 단계로 해결했다. (a) cron 라인에서 monitor.sh 를 **절대 경로**로 호출 — PATH 에 의존 안 함. (b) monitor.sh 가 자기 안에서 `/etc/profile.d/agent-app.sh` 를 다시 source — `AGENT_HOME` 같은 변수가 항상 들어오게 보장. stdout/stderr 는 `/tmp/monitor.cron.log` 로 캡처해 실패 시 즉시 원인을 볼 수 있게 했다.

### Q4. UFW 와 firewalld 중 UFW 를 선택한 이유는?

Ubuntu 22.04 의 기본 방화벽 프론트엔드가 UFW 다. firewalld 는 RHEL/Fedora 계열의 기본이고, Ubuntu 에 깔 수는 있지만 추가 설치가 필요하다. 이번 미션의 OS 가 Ubuntu 이므로 표준 도구를 택했다. 둘 다 내부적으로는 netfilter/iptables/nftables 를 부르는 프론트엔드라 능력 면에서는 동등하다.

### Q5. 기존 SSH 세션이 sshd 재시작·UFW enable 후에도 끊기지 않은 이유는?

(a) sshd 를 `systemctl restart` 해도 이미 fork 된 자식 sshd 프로세스(각 세션) 는 그대로 살아 있어서 기존 TCP 연결이 유지된다. (b) UFW 는 활성화될 때 기본적으로 `state ESTABLISHED,RELATED ACCEPT` 룰을 먼저 깔아두기 때문에 이미 established 된 연결은 통과시킨다. 다만 **세션이 어떤 이유로든 끊기면 22번으로 재접속은 불가**하므로, 호스트의 VirtualBox 포트 포워딩을 guest:20022 로 미리 바꿔두는 절차를 함께 진행했다.

### Q6. `monitor.sh` 가 `sudo` 없이 도는데 어떻게 `/var/log/agent-app` 에 쓰나요?

`/var/log/agent-app` 디렉토리 자체가 `agent-core` 그룹에 R/W 권한이 주어져 있고(`drwxrws--- root:agent-core`), agent-admin 이 agent-core 그룹 멤버이기 때문이다. setgid 덕분에 새로 생성되는 `monitor.log` 도 자동으로 agent-core 그룹이 되어 동일한 권한이 적용된다. 즉 sudo 가 아니라 **그룹 멤버십**으로 쓰기가 허용된다.

### Q7. 왜 `logrotate` 가 아니라 자체 회전 로직?

`logrotate` 는 강력하지만 (a) 별도 설정 파일(`/etc/logrotate.d/agent-app`) 필요, (b) 호출 주기가 기본 1일(cron.daily) — 단위 시간 안에 10MB 넘으면 회전 못함, (c) 의존성이 더 늘어남. 미션이 "방법 자유" 라고 명시했고 monitor.sh 가 매분 도는 만큼 **그 안에서 회전을 직접 처리**하는 게 더 단순하고 빠른 회전을 보장한다. 단점은 회전이 monitor.sh 실행 시에만 일어난다는 것 — 앱 다운으로 monitor.sh 가 `exit 1` 하면 그 시점부터는 회전도 안 된다.

### Q8. 보너스(`report.sh`, 7일 압축/30일 삭제) 는 왜 안 했나요?

본 미션의 필수 범위는 [§4](MISSION.md) 까지이고, 8개 체크리스트도 거기에 대응한다. 보너스 [§5](MISSION.md) 는 시간 여유가 있을 때 추가할 수 있는 영역이라 우선 필수 부분을 견고히 마무리하는 데 집중했다. 보너스를 구현한다면 (a) `report.sh` 는 monitor.log 를 `awk` 로 컬럼 분리해 min/max/avg 계산, (b) 압축/삭제는 `find -mtime` + `gzip` + `mv` 의 조합으로 60~80 라인 안에 완성 가능하다.

---

## 7. 한 줄 자기 점검 체크리스트

평가 직전 마지막 점검용. **30초 안에 막힘없이** 답할 수 있어야 통과.

- [ ] 산출물 2개의 이름·위치·역할을 한 문장으로 말할 수 있다.
- [ ] 8개 체크리스트 각각이 EXECUTION_REPORT 의 어느 § 에 있는지 안다.
- [ ] **목표 1**: 22 → 20022 + root 차단이 왜 "기본" 보안인지 30초 답.
- [ ] **목표 2**: "기본 거부 + 명시적 허용" 원칙과 `ufw status` 의 어느 부분을 보면 되는지.
- [ ] **목표 3**: 그룹(common/core) 과 ACL(default) 이 각각 어떤 문제를 푸는지.
- [ ] **목표 4**: `/etc/profile.d` + monitor.sh 의 self-source 가 왜 둘 다 필요한지.
- [ ] **목표 5**: monitor.sh 의 4단계(env load / health / resource / log) 를 순서대로 말할 수 있다.
- [ ] **목표 6**: cron + 회전이 왜 "한 묶음" 인지 (자동 수집은 보존 정책을 강제로 동반).
- [ ] §5.1 (AGENT_KEY_PATH 불일치) 와 §5.2 (CPU 파싱 버그) 를 발견·해결한 과정을 짧게 설명할 수 있다.
- [ ] FAQ 8개 중 무작위 3개를 골랐을 때 모두 답할 수 있다.

---

> 본 가이드는 평가 통과만을 위한 것이 아니라, **이 미션에서 만든 시스템이 한 달 뒤에도 자기 머릿속에 남도록** 정리한 것이다. 부족한 부분은 자기 말로 다시 풀어 보충하면서 사용하면 된다.
