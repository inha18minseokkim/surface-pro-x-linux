# 셀룰러 모뎀 — Snapdragon X24 LTE (Issue #7)

## 아키텍처 (2026-06-12 실기기 ACPI/PnP로 확정 — 2차 정정)

조사 경과:
1. 이슈 초안: "discrete SDX24, PCIe, MHI device id 패치 필요" (가정)
2. 1차 정정: 메인라인에 SDX24(17cb:0304) MHI 지원이 이미 존재 → 패치 불필요
3. **2차 정정 (실기기 확정): SPX의 X24는 PCIe 장치가 아니라 SoC 내장 MPSS다.**
   - PCIe 버스에 모뎀 없음 (NVMe만 존재, 나머지 포트 빈 상태)
   - ACPI `QCOM041E` "Snapdragon (TM) X24 LTE Modem" 플랫폼 장치 + IPA/IPC
     router/rmtfs/PIL 보조 장치들 → 폰과 같은 통합 모뎀 구조

## 리눅스 스택 (통합 모뎀 경로)

```
remoteproc_mpss (CONFIG_QCOM_Q6V5_PAS)
  └─ firmware: qcom/sc8180x/MICROSOFT/qcmpss8180_nm.mbn (확정, 추출 완료)
       ↓ 모뎀 DSP 기동
GLINK/SMEM (CONFIG_RPMSG_QCOM_GLINK_SMEM)
  ├─ QRTR (CONFIG_QRTR + QRTR_SMD) ← QMI 제어 채널
  └─ IPA (CONFIG_QCOM_IPA) + RMNET ← 데이터 경로 (rmnet_ipa0)
       ↓ 커널
유저스페이스:
  rmtfs 데몬 (SIM/캘리브레이션 데이터, qcom,rmtfs-mem 사용)
  ModemManager (qrtr:// 경로, ≥1.18) + libqmi → NetworkManager
```

DTS(#3): `&remoteproc_mpss` 활성 + `mpss_mem`/`rmtfs_mem` carve-out.
config: `configs/surface-pro-x.config`의 cellular 섹션.

## 전제 조건

1. #3 DT 부팅 + reserved-memory 주소 정확성 (carve-out 틀리면 MPSS 기동 시 hang)
2. firmware: `qcmpss8180_nm.mbn` (이미 `firmware-staging/`에 추출됨)
3. rmtfs 유저스페이스 데몬 (qrtr/rmtfs 패키지) — Windows 파티션의 modem
   NV 데이터 경로 확인 필요

## 검증 절차 (리눅스 부팅 후)

```bash
cat /sys/class/remoteproc/remoteproc*/name   # mpss 확인
echo start > /sys/class/remoteproc/remoteprocN/state
dmesg | grep -E "remoteproc|qrtr|ipa"
qrtr-lookup                                   # QMI 서비스 목록
ip link | grep rmnet
mmcli -L && mmcli -m 0 --simple-connect="apn=<APN>"
```

## 예상 문제와 대응

| 문제 | 대응 |
|------|------|
| MPSS 기동 즉시 crash/hang | mpss_mem carve-out 주소 불일치 → UEFI memmap 재확인 |
| qrtr 서비스 안 보임 | glink/smem 채널 문제 → remoteproc 로그, qcom_smem 확인 |
| SIM 미인식 | rmtfs 데몬 미기동 or NV 데이터 경로 오류 |
| IPA probe 실패 | sc8180x IPA 메인라인 지원 버전 확인 (ipa v4.x), DT ipa 노드 추가 필요 가능 |
| 연결은 되나 매우 느림 | IPA 대신 BAM-DMUX fallback 여부 확인 |

## 참고: MHI/SDX24 (잘못된 가설이었지만 기록 유지)

메인라인 `drivers/bus/mhi/host/pci_generic.c`에는 discrete SDX24(17cb:0304)
지원이 존재한다. 이는 SDX24를 PCIe 카드로 쓰는 다른 기기용이며 SPX와 무관.
