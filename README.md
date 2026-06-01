# 디지털 도어락 - FND 출력 모듈 (장현석 담당)

> **과목:** 디지털 시스템 설계
> **팀 프로젝트:** FPGA 기반 디지털 도어락
> **담당:** 장현석 — FND(7-Segment) 출력 모듈
> **HDL/툴:** VHDL · Intel(Altera) Quartus
> **타깃 보드:** HBE-Combo II-SE (Altera Cyclone II EP2C8Q208C8)

---

## 1. 본 폴더의 목적

본 폴더는 팀 프로젝트 **「FPGA 기반 디지털 도어락」** 중 **장현석이 단독으로 책임지는 FND 출력 모듈** 의 모든 산출물을 한 곳에 정리한 작업 패키지입니다.
역할별 산출물 명세(`장현석_역할별내용.pptx`)와 통합 발표자료(`디시설_오후_프로젝트.pptx`)의 요구사항을 기반으로 작성되었습니다.

전체 팀에서 장현석 담당 산출물(`장현석_역할별내용.pptx` 슬라이드 6):
- `fnd_driver.vhd` — VHDL 모듈 본체 (합성 대상)
- `fnd_driver_tb.vhd` — 테스트벤치 (시뮬레이션 전용)
- `fnd_driver.qsf` — Quartus 핀 배정 파일
- 시뮬레이션 파형 · 보드 동작 검증

본 폴더는 위 요구사항을 충족하면서, 모듈을 **5개 sub-block** 으로 잘 분리해 가독성·재사용성·시뮬레이션 단위까지 끌어올린 구조입니다.

---

## 2. 폴더 구조

> **★ 본 프로젝트는 VHDL 과 Verilog 두 버전을 모두 제공한다.**
> 팀 통합 언어는 **Verilog 로 확정**, 1kHz 단일 클럭 도메인 사용.
> Verilog 버전에는 팀 명세 대조 피드백을 반영한 `fnd_team_adapter.v` 가 추가되어 있다 ([docs/08](docs/08_팀FSM_연동_피드백반영.md) 참조).
> VHDL 버전은 학습/시뮬레이션 비교용으로 유지된다.

```
장현석_FND_프로젝트/
├── README.md                       ← (지금 보고 있는 파일) 전체 안내
│
├── docs/                           ← 이론 정리 (마크다운, 언어 공통)
│   ├── 01_프로젝트_개요와_나의_역할.md
│   ├── 02_FND_하드웨어_기초.md
│   ├── 03_7세그먼트_디코더_이론.md
│   ├── 04_시분할_멀티플렉싱_이론.md
│   ├── 05_마스킹과_FSM연동_이론.md
│   ├── 06_VHDL_모듈_상세_설명.md   ← 코드 한줄한줄 해설 (VHDL 기준, Verilog 도 구조 동일)
│   ├── 07_통합과_인터페이스_명세.md
│   └── 08_팀FSM_연동_피드백반영.md ← ★ 1kHz 변경 + 어댑터 (Verilog)
│
├── src/                            ← 합성 대상 (Quartus에 추가할 파일)
│   ├── vhdl/                       ← VHDL 5개
│   │   ├── seg7_decoder.vhd
│   │   ├── clk_divider.vhd
│   │   ├── digit_scanner.vhd
│   │   ├── display_policy.vhd
│   │   └── fnd_driver.vhd          ← VHDL TOP
│   └── verilog/                    ← Verilog (팀 통합 언어, 1kHz 도메인 default)
│       ├── seg7_decoder.v
│       ├── clk_divider.v
│       ├── digit_scanner.v
│       ├── display_policy.v
│       ├── fnd_driver.v            ← FND 코어 TOP
│       ├── fnd_team_adapter.v     ← ★ 팀 FSM 인터페이스 어댑터
│       └── top_standalone.v        ← 단독 보드 시연 래퍼 (자동 순환)
│
├── testbench/                      ← 시뮬레이션 전용 (합성 대상 아님)
│   ├── vhdl/
│   │   ├── tb_seg7_decoder.vhd
│   │   ├── tb_clk_divider.vhd
│   │   ├── tb_digit_scanner.vhd
│   │   ├── tb_display_policy.vhd
│   │   └── tb_fnd_driver.vhd       ← VHDL 통합 TB
│   └── verilog/
│       ├── tb_seg7_decoder.v
│       ├── tb_clk_divider.v
│       ├── tb_digit_scanner.v
│       ├── tb_display_policy.v
│       └── tb_fnd_driver.v         ← Verilog 통합 TB
│
├── sim/                            ← ModelSim/Questa 시뮬레이션 스크립트
│   ├── run_all_vhdl.do             ← VHDL 전체 컴파일·실행
│   ├── run_all_verilog.do          ← Verilog 전체 컴파일·실행
│   └── README_시뮬레이션.md
│
└── quartus/                        ← Quartus 프로젝트 자료
    ├── fnd_driver_vhdl.qsf         ← VHDL 핀 배정 (HBE-Combo II-SE)
    ├── fnd_driver_verilog.qsf      ← Verilog 핀 배정 (동일 핀)
    ├── 핀배치_가이드.md
    └── 컴파일_가이드.md
```

---

## 3. 빠른 시작 (Quick Start)

### A. Quartus에서 단독 합성하기 — 언어 택일

#### VHDL 버전
1. Quartus Prime 새 프로젝트 생성 (Top entity: `fnd_driver`)
2. `src/vhdl/` 의 모든 `.vhd` 파일을 프로젝트에 추가
3. `quartus/fnd_driver_vhdl.qsf` 의 핀 할당을 본인 프로젝트의 `.qsf` 에 복사
4. Device 선택: **EP2C8Q208C8**
5. Compile (Ctrl+L) → USB Blaster 로 다운로드

#### Verilog 버전
1. Quartus Prime 새 프로젝트 생성 (Top entity: `fnd_driver`)
2. `src/verilog/` 의 모든 `.v` 파일을 프로젝트에 추가
3. `quartus/fnd_driver_verilog.qsf` 핀 할당 복사
4. 이하 동일

> ⚠️ 두 버전을 동시에 한 Quartus 프로젝트에 넣지 말 것 (top entity `fnd_driver` 이름 충돌).

### B. ModelSim 에서 시뮬레이션 하기

```tcl
# ModelSim Transcript 창에서
cd <이 폴더 경로>/sim

do run_all_vhdl.do        # VHDL 버전
# 또는
do run_all_verilog.do     # Verilog 버전
```

개별 단위 검증:
```tcl
# VHDL
vlib work
vcom ../src/vhdl/seg7_decoder.vhd ../testbench/vhdl/tb_seg7_decoder.vhd
vsim work.tb_seg7_decoder ; run -all

# Verilog
vlib work
vlog ../src/verilog/seg7_decoder.v ../testbench/verilog/tb_seg7_decoder.v
vsim work.tb_seg7_decoder ; run -all
```

---

## 4. 팀 내 인터페이스 (상위 모듈에서 본 모듈을 인스턴스화 할 때)

본 모듈의 entity port (자세히는 [docs/07_통합과_인터페이스_명세.md](docs/07_통합과_인터페이스_명세.md) 참고):

| 신호명 | 방향 | 폭 | 의미 | 전달 팀원 |
|---|---|---|---|---|
| `clk` | in | 1 | 보드 1MHz 시스템 클럭 | 보드 (PIN_T2 가정) |
| `reset_n` | in | 1 | 비동기 리셋 (active-low) | 보드 push button |
| `digit_data` | in | 16 | 4자리 BCD (각 4비트) | 정용성 (비교/저장 모듈) |
| `input_count` | in | 3 | 현재 입력된 자릿수 (0~4) | 손동한 (입력 처리) |
| `mask_enable` | in | 1 | 마스킹(****) 모드 ON | 이서영 (Top FSM) |
| `fsm_state` | in | 3 | 현재 FSM 상태 (6개) | 이서영 (Top FSM) |
| `fnd_seg` | out | 8 | a,b,c,d,e,f,g,dp (active-high) | 보드 7-Seg |
| `fnd_com` | out | 4 | COM1~4 자리 선택 (active-low) | 보드 7-Seg |

FSM 상태 인코딩 (3-bit):
| 값 | 상태 | FND 표시 |
|---|---|---|
| `000` | IDLE | 빈 화면 (LCD 안내가 담당) |
| `001` | INPUT | `-` 마스킹 (입력 자릿수만큼 dash) |
| `010` | CHECK | `----` ↔ blank 깜빡임 |
| `011` | UNLOCK | 빈 화면 |
| `100` | ALARM | `FAIL` |
| `101` | CHANGE | `-` 마스킹 (INPUT 과 동일) |

> 마스킹을 `*` (a~g 전체 점등) 가 아니라 `-` (g 만) 로 채택한 이유는 `*` 가 숫자 `8` 과 시각적으로 동일해서 발생할 충돌을 피하기 위함. [docs/05](docs/05_마스킹과_FSM연동_이론.md#51-비밀번호-마스킹이란) 참조.

---

## 5. 학습/제출용 문서 읽는 순서 (권장)

처음 보는 사람이 이해할 수 있도록 다음 순서로 읽기를 권장합니다:

1. [docs/01_프로젝트_개요와_나의_역할.md](docs/01_프로젝트_개요와_나의_역할.md) - 큰 그림 잡기
2. [docs/02_FND_하드웨어_기초.md](docs/02_FND_하드웨어_기초.md) - FND란 무엇인가
3. [docs/03_7세그먼트_디코더_이론.md](docs/03_7세그먼트_디코더_이론.md) - 디코더의 원리
4. [docs/04_시분할_멀티플렉싱_이론.md](docs/04_시분할_멀티플렉싱_이론.md) - 4자리 점등 원리
5. [docs/05_마스킹과_FSM연동_이론.md](docs/05_마스킹과_FSM연동_이론.md) - 비밀번호 마스킹 정책
6. [docs/06_VHDL_모듈_상세_설명.md](docs/06_VHDL_모듈_상세_설명.md) - 실제 코드 해설
7. [docs/07_통합과_인터페이스_명세.md](docs/07_통합과_인터페이스_명세.md) - 팀원과의 연결

---

## 6. 일정 (장현석_역할별내용.pptx 기준)

| 주차 | 작업 | 본 폴더의 산출물 |
|---|---|---|
| 1주차 (단독) | 디코더·분주기·자리선택·마스킹 작성 | `src/*.vhd` |
| 2주차 (단독) | 테스트벤치·시뮬레이션·보드 단독 다운 | `testbench/*.vhd`, `sim/`, `quartus/` |
| 3주차 (통합) | A(이서영)의 Top에 인스턴스, B·C 신호 연결 | `docs/07_통합과_인터페이스_명세.md` |
| 4주차 (마무리) | 예외 처리·데모 시나리오·발표 자료 | 본 README 및 docs/ |

---

## 7. 참고 자료

- `디시설_오후_프로젝트.pptx` — 팀 통합 발표자료 (전체 시스템)
- `장현석_역할별내용.pptx` — 본인 역할 상세 명세
- HBE-Combo II-SE 사용자 매뉴얼 (보드 데이터시트)
- Altera Cyclone II Device Handbook
