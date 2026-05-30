# B1-1 — 시스템 관제 자동화 스크립트 개발

리눅스 서버의 기본 보안·권한 체계·실행 환경을 직접 구축하고, `monitor.sh` 로 프로세스/포트/리소스를 주기적으로 관제·로깅하는 미션의 구현 저장소다. 미션이 요구하는 **최종 결과물이 모두 완성된 상태**이며, 이 README 는 그 결과물과 문서로 연결되는 진입점이다.

> 미션 원문: [docs/MISSION.md](docs/MISSION.md)

---

## 프로젝트 소개

서버 운영 엔지니어처럼 다중 사용자 환경의 권한 관리와 네트워크 보안부터, 시스템 리소스 관제·로그 자동화까지를 직접 설계·구현한다. 전체 흐름은 다음과 같다.

1. **기본 보안 / 네트워크** — SSH 포트를 `20022` 로 변경하고 root 원격 로그인을 차단한다. UFW 방화벽을 활성화해 인바운드는 `20022/tcp`(SSH)·`15034/tcp`(APP) 두 포트만 허용한다.
2. **계정 / 그룹 / 권한** — 역할 기반 계정(`agent-admin`/`agent-dev`/`agent-test`)과 그룹(`agent-common`/`agent-core`)을 만들고, setgid + ACL 로 "공유 디렉토리"와 "보안 디렉토리"를 분리한다.
3. **실행 환경** — `AGENT_HOME` 등 환경 변수를 시스템 전역에 고정하고, 제공된 Python 앱을 일반 계정으로 실행해 Boot Sequence 5단계 통과와 `0.0.0.0:15034` LISTEN 을 확인한다.
4. **시스템 관제 자동화** — `monitor.sh` 로 프로세스/포트 Health Check, 방화벽·리소스 점검, 임계값 경고, 로그 기록·회전을 수행한다.
5. **자동 실행** — `agent-admin` 의 crontab 에 매분 실행을 등록해 `monitor.log` 가 자동으로 누적되게 한다.

자동화 스크립트는 제약 조건에 따라 **Bash 로만** 구현했다.

---

## 최종 결과물

미션 [§2](docs/MISSION.md) 가 요구하는 2개 산출물.

| # | 산출물 | 위치 | 설명 |
| --- | --- | --- | --- |
| ① | 요구사항 수행 내역서 | [docs/EXECUTION_REPORT.md](docs/EXECUTION_REPORT.md) | 8개 필수 증거 자료를 명령 / 기대 출력 / 실측 출력 4단 구조로 정리 |
| ② | 자동화 스크립트 소스 | [scripts/monitor.sh](scripts/monitor.sh) | Health Check + 리소스 수집 + 임계값 경고 + 로그 회전을 수행하는 Bash 스크립트 |

---

## 디렉토리 구조

```text
B1-1/
├─ README.md                     ← 현재 문서 (진입점)
├─ docs/                          프로젝트 문서
│  ├─ MISSION.md                  미션 원문 (요구사항 정의)
│  ├─ IMPLEMENTATION_GUIDE.md     실행 가이드 (어떻게)
│  ├─ COMMAND_REFERENCE.md        명령어 레퍼런스 (무슨 의미)
│  ├─ EXECUTION_REPORT.md         요구사항 수행 내역서 = 산출물 ①
│  └─ STUDY_GUIDE.md              결과물 해설 (왜)
├─ scripts/
│  └─ monitor.sh                  시스템 관제 스크립트 = 산출물 ②
└─ agent-app/                     제공 바이너리 (linux-x86 / linux-arm64)
```

---

## 문서 안내

| 문서 | 한 줄 역할 | 이런 때 본다 |
| --- | --- | --- |
| [docs/MISSION.md](docs/MISSION.md) | 미션 원문 — 요구사항·산출물·평가 기준 정의 | 무엇을 만들어야 하는지 |
| [docs/IMPLEMENTATION_GUIDE.md](docs/IMPLEMENTATION_GUIDE.md) | **어떻게 했는가** — 실행 → 검증 → 기대 출력 순의 단계별 가이드 | 처음부터 끝까지 재현할 때 |
| [docs/COMMAND_REFERENCE.md](docs/COMMAND_REFERENCE.md) | **무슨 의미인가** — 모든 명령·플래그 한 줄씩 해설 | 특정 명령의 동작이 궁금할 때 |
| [docs/EXECUTION_REPORT.md](docs/EXECUTION_REPORT.md) | **무엇을 했는가(증거)** — 8개 체크리스트 실측 결과 (산출물 ①) | 수행 결과·증거를 확인할 때 |
| [docs/STUDY_GUIDE.md](docs/STUDY_GUIDE.md) | **왜 그렇게 했는가** — 설계 근거 + 평가 질의응답 대비 | 결과물을 말로 설명해야 할 때 |
| [scripts/monitor.sh](scripts/monitor.sh) | 시스템 관제 자동화 스크립트 (산출물 ②) | 스크립트 구현을 볼 때 |

---

## 추천 읽기 순서

목적에 따라 다음 경로로 본다.

- **미션을 처음 접한다면** → [MISSION.md](docs/MISSION.md) 로 요구사항을 파악한 뒤 [STUDY_GUIDE.md](docs/STUDY_GUIDE.md) 로 전체 그림을 잡는다.
- **직접 환경을 재현하려면** → [IMPLEMENTATION_GUIDE.md](docs/IMPLEMENTATION_GUIDE.md) 를 순서대로 따라간다. 모르는 명령이 나오면 [COMMAND_REFERENCE.md](docs/COMMAND_REFERENCE.md) 의 같은 § 로 점프한다.
- **수행 결과·증거를 확인하려면** → [EXECUTION_REPORT.md](docs/EXECUTION_REPORT.md) 의 8개 체크리스트를 본다.
- **결과물을 설명·발표하려면** → [STUDY_GUIDE.md](docs/STUDY_GUIDE.md) 의 과제 목표별 핵심 답변과 FAQ 를 본다.

---

## monitor.sh 한눈에

[scripts/monitor.sh](scripts/monitor.sh) 는 매 실행마다 다음 4단계를 수행한다.

1. **환경 변수 로드** — cron 환경은 `/etc/profile.d/*` 를 자동 source 하지 않으므로 스크립트가 직접 끌어온다(미설정 시 안전한 기본값으로 폴백).
2. **Health Check (실패 시 종료)** — `agent_app` 프로세스와 `15034` 포트 LISTEN 을 확인하고, 비정상이면 `exit 1`.
3. **방화벽 · 리소스 점검 (경고만)** — UFW 비활성 시 `[WARNING]`(종료하지 않음), 이어서 CPU/MEM/DISK 사용률을 수집한다.
4. **로그 기록 · 회전** — 결과를 콘솔 출력하고 로그 파일에 1줄 append. 파일이 10MB 를 넘으면 `.1`~`.10` 로 회전한다.

| 항목 | 값 |
| --- | --- |
| 임계값 (경고) | CPU > 20% · MEM > 10% · DISK > 80% |
| 로그 파일 | `/var/log/agent-app/monitor.log` |
| 로그 포맷 | `[YYYY-MM-DD HH:MM:SS] PID:.. CPU:..% MEM:..% DISK_USED:..%` |
| 로그 회전 | 최대 10MB / 10개 파일 |

배포·실행·cron 등록 절차는 [IMPLEMENTATION_GUIDE.md §6~§7](docs/IMPLEMENTATION_GUIDE.md) 을 참조한다.

---

## 개발 환경

- **OS**: Ubuntu 22.04 LTS(또는 동등 리눅스), `bash`
- **구현 언어**: 자동화 스크립트는 Bash 전용(Python 등 대체 금지), 필요 시에만 `sudo` 사용
- **제공 앱**: `agent-app/` 의 바이너리는 "실행 대상"이며, 과제의 핵심은 관제·자동화 스크립트 구현이다

자세한 제약 조건은 [MISSION.md §6~§7](docs/MISSION.md) 을 참조한다.
