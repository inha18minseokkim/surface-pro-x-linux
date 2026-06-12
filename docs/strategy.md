# 포팅 전략 (Issue #1)

## 목표 정의

1. **1단계 — 부팅**: USB에서 ARM64 커널 부팅, 시리얼/화면 출력 확인 (#2, #3)
2. **2단계 — 스토리지**: 내장 NVMe 인식, Ubuntu rootfs 설치 (#4)
3. **3단계 — 기본 사용성**: 디스플레이(GPU), Wi-Fi, 키보드 (#5, #6, #8)
4. **4단계 — 셀룰러**: X24 모뎀을 MHI/WWAN 스택으로 활성화 (#7)
5. **5단계 — 잔여 하드웨어**: 카메라/센서 (#9, 펌웨어 확보 전까지 blocked)

## 두 가지 부팅 경로

### A. ACPI 경로 (단기, 검증됨)
- Surface UEFI가 제공하는 ACPI 테이블로 부팅
- linux-surface discussion #636: 커널 5.14/5.15에서 부팅 성공 사례
- 장점: DTS 없이 부팅 가능 → 초기 bring-up 빠름
- 단점: Qualcomm SoC의 클럭/전원 관리가 ACPI로 기술되지 않아
  GPU·모뎀 등 대부분의 주변장치를 못 씀

### B. Device Tree 경로 (장기, 본선)
- `sc8180xp.dtsi` + `sc8180xp-microsoft-surface-pro-x.dts` 작성 (#3)
- sc8180x(SQ1, 커널 6.0+ 메인라인)를 베이스로 fork
- 모든 주변장치 지원의 전제 조건

**결론: A로 부팅을 먼저 확보하고, B를 병행 개발한다.**

## sc8180x → sc8180xp 차이점 (역공학 대상)

| 항목 | sc8180x (SQ1) | sc8180xp (SQ2) | 확인 방법 |
|------|---------------|----------------|-----------|
| GPU | Adreno 675/680 | Adreno 680 (클럭 상향) | Windows 드라이버 inf, ACPI DSDT |
| CPU 클럭 | 최대 3.0GHz | 최대 3.15GHz | ACPI _CPC |
| PMIC | PM8150 계열 | 동일 계열, 레일 구성 일부 상이 | ACPI 덤프 비교 |

ACPI 테이블 덤프(Windows에서 `acpidump`)가 1차 자료다.
aarch64-laptops 레포에 유사 SoC(Acer Spin 7, Lenovo IdeaPad 5G) 덤프가 있어 비교 가능.

## 셀룰러 (X24) 접근법 — #7 요약

X24(SDX24)는 PCIe로 연결된 모뎀이며, 메인라인의 MHI(Modem Host Interface) 버스 +
WWAN 서브시스템으로 접근한다:

```
PCIe → mhi_pci_generic (VID/PID 등록 필요) → MHI channels
  ├─ QMI/QRTR (제어)
  └─ MBIM (데이터) → wwan0 인터페이스 → ModemManager
```

- `drivers/bus/mhi/host/pci_generic.c` 에 SDX24 device id 항목 추가가 핵심 패치
- 모뎀 firmware blob은 Windows 파티션에서 추출 (firmware/README.md 참조)
- 유저스페이스: ModemManager ≥ 1.18 + libmbim/libqmi

## 리스크

1. **펌웨어 blob 라이선스**: 재배포 불가 → 사용자가 자기 기기 Windows에서 추출하는
   스크립트 제공으로 우회
2. **클럭/전압 테이블 부정확** → SoC 불안정. Gen1 보수적 값으로 시작, 점진 상향
3. **Secure Boot**: 비활성화 가능(UEFI 설정)하므로 블로커 아님
4. **검증 하드웨어**: 모든 단계는 실기기(SPX SQ2)에서만 최종 검증 가능
