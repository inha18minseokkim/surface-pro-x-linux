# Device Tree 작업 공간 (Issue #3)

여기에 들어갈 파일:

- `sc8180xp.dtsi` — SoC 공통 정의. 메인라인 `arch/arm64/boot/dts/qcom/sc8180x.dtsi`
  를 베이스로 sc8180xp 차이(GPU 클럭, CPU OPP, PMIC 레일)를 반영.
- `sc8180xp-microsoft-surface-pro-x.dts` — Surface Pro X 보드 정의.
  참고: `sc8180x-lenovo-flex-5g.dts` (같은 세대 SQ1 머신, 메인라인 존재)

`scripts/build-kernel.sh` 가 빌드 시 이 디렉터리의 .dts/.dtsi를 커널 트리의
`arch/arm64/boot/dts/qcom/` 으로 복사하고 Makefile 항목을 추가한다.

## 1차 자료: ACPI 덤프

Windows가 설치된 실기기에서:

```powershell
# 관리자 PowerShell, acpica-tools (iasl/acpidump) 필요
acpidump -b -n DSDT
iasl -d dsdt.dat   # → dsdt.dsl
```

DSDT에서 추출할 정보: GPIO 핀 배치, I2C/SPI 버스 주소(터치/키보드),
PMIC 레일 구성, PCIe 루트포트 (NVMe / Wi-Fi / 모뎀 매핑).
덤프 결과는 `dts/acpi-dumps/` 에 커밋한다.
