# 셀룰러 모뎀 — Snapdragon X24 LTE (Issue #7)

## 핵심 결론 (2026-06 메인라인 소스로 검증)

**SDX24는 이미 메인라인 MHI 드라이버가 지원한다.** 이슈에서 가정했던
"pci_generic.c에 device id 추가 패치"는 불필요.

`drivers/bus/mhi/host/pci_generic.c` (메인라인):

```c
static const struct mhi_pci_dev_info mhi_qcom_sdx24_info = {
        .name = "qcom-sdx24",
        .edl = "qcom/prog_firehose_sdx24.mbn",
        .config = &modem_qcom_v1_mhiv_config,
        .bar_num = MHI_PCI_DEFAULT_BAR_NUM,
        .dma_data_width = 32,
        .sideband_wake = true,
};
...
{ PCI_DEVICE(PCI_VENDOR_ID_QCOM, 0x0304),
        .driver_data = (kernel_ulong_t) &mhi_qcom_sdx24_info },
```

- PCI ID: `17cb:0304`
- `.fw` 필드 없음 → 정상 부팅 시 호스트가 SBL을 밀어넣을 필요 없음
  (EDL 경로는 복구용 firehose만 정의됨)
- `sideband_wake = true` → DT의 wake GPIO가 동작해야 함 (#3의 `&pcie3` 노드)

## 스택 구성

```
PCIe(&pcie3) → mhi_pci_generic → MHI 채널
  ├─ QMI/QRTR  (제어: CONFIG_QRTR_MHI)
  ├─ MBIM      (데이터: CONFIG_MHI_WWAN_MBIM → wwan0)
  └─ DIAG/DUN  (디버그)
        ↑ 커널
        ↓ 유저스페이스
ModemManager(≥1.18) + libmbim/libqmi → NetworkManager
```

커널 config은 `configs/surface-pro-x.config`에 이미 포함:
`MHI_BUS_PCI_GENERIC`, `MHI_WWAN_CTRL`, `MHI_WWAN_MBIM`, `QRTR`, `QRTR_MHI`, `WWAN`.

## 전제 조건

1. **#3**: `&pcie3` 노드 (DT 경로) 또는 **#4 패치** (ACPI 경로) — 모뎀이 PCIe에서 보여야 함
2. 모뎀이 자체 플래시에서 부팅하므로 별도 host firmware는 기본 불필요.
   단, SIM/RF 캘리브레이션 데이터(rmtfs) 경로는 실기기에서 확인 필요
   — DT의 `rmtfs_mem` + `qcom,rmtfs-mem` 데몬(rmtfs 유저스페이스) 조합

## 검증 절차 (실기기)

```bash
lspci -nn | grep 17cb:0304          # 모뎀 PCIe enumerate
dmesg | grep mhi                     # mhi0 등록, 채널 기동
ls /dev/wwan*                        # wwan0mbim0 / wwan0qmi0
mmcli -L                             # ModemManager 모뎀 인식
mmcli -m 0 --simple-connect="apn=<APN>"
```

## 예상 문제와 대응

| 문제 | 대응 |
|------|------|
| 모뎀이 lspci에 안 보임 | #4 quirk(ACPI) 또는 &pcie3 GPIO 확인(DT). 모뎀 전원 레일이 EC/PMIC 제어일 가능성 → ACPI DSDT에서 _ON/_OFF 메서드 추적 |
| mhi 채널 timeout | sideband wake GPIO 미동작 의심 → DT wake-gpios 재확인 |
| 전파는 잡히나 연결 불가 | FCC unlock 필요 가능성 (WoA 노트북 공통 이슈) → ModemManager fcc-unlock 스크립트 (`/usr/share/ModemManager/fcc-unlock.available.d/`) |
| SIM 미인식 | rmtfs/uim 경로 문제 → qrtr 서비스 목록 확인 (`qrtr-lookup`) |
