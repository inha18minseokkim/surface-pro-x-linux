# Firmware Blobs

**blob 자체는 라이선스(Qualcomm proprietary) 때문에 이 레포에 커밋하지 않는다.**
사용자가 자신의 기기에서 추출하거나 linux-surface 레포에서 받는다.

## 1. linux-surface aarch64-firmware (Wi-Fi, GPU 등)

```bash
git clone https://github.com/linux-surface/aarch64-firmware
sudo cp -r aarch64-firmware/firmware/* /lib/firmware/
```

## 2. Windows 파티션에서 추출 (모뎀 X24 등)

Windows의 Qualcomm 드라이버 패키지에 firmware가 포함되어 있다:

```
C:\Windows\System32\DriverStore\FileRepository\
  qcsubsys*.inf_arm64_*\   # 서브시스템 firmware
  qcwwan*.inf_arm64_*\     # WWAN(모뎀) firmware ← X24
  qcadreno*.inf_arm64_*\   # GPU firmware
```

리눅스 부팅 후 Windows 파티션을 마운트해 복사하거나, Windows에서 미리 USB로 백업.

배치 위치 (커널이 찾는 경로):

```
/lib/firmware/qcom/sc8180x/...     # SoC firmware (TZ, GPU 등)
/lib/firmware/ath11k/WCN3998/...   # Wi-Fi
/lib/firmware/qcom/sdx24/...       # 모뎀 (MHI가 로드)
```

정확한 파일 이름 매핑은 각 드라이버 이슈(#5, #6, #7)에서 확정한다.
