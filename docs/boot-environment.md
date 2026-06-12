# 부팅 환경 구성 — UEFI / GRUB / Secure Boot (Issue #2)

## 0. 전제

- Surface Pro X는 ARM64 UEFI 펌웨어. 부트로더도 ARM64(`grubaa64.efi`)여야 한다.
- 초기 bring-up은 **USB 부팅**으로 진행한다. 내장 NVMe는 #4 quirk 해결 전까지
  커널에서 안 보일 수 있으므로, rootfs도 USB에 둔다.

## 1. Secure Boot 비활성화

Surface 펌웨어는 기본적으로 Microsoft 서명 부트로더만 허용한다.

1. 전원 끔 → **볼륨 업 + 전원** 길게 눌러 UEFI 설정(Surface UEFI) 진입
2. **Security → Secure Boot → None** 선택
3. **Boot configuration**에서 "USB Storage"를 최상단으로
4. 저장 후 재부팅

(장기적으로 shim + MOK 등록으로 Secure Boot를 켠 채 부팅하는 옵션이 있으나,
bring-up 단계에서는 불필요한 복잡도이므로 비활성화로 간다.)

## 2. ARM64 GRUB 확보

### 옵션 A — linux-surface known-good 이미지 (권장)

https://github.com/linux-surface/grub-image-aarch64 의 릴리스에서
`grubaa64.efi` 를 받는다. `scripts/make-boot-usb.sh` 가 자동으로 처리.

### 옵션 B — 직접 빌드

```bash
sudo apt install grub-efi-arm64-bin
grub-mkimage -O arm64-efi -o grubaa64.efi \
    -p /EFI/ubuntu \
    part_gpt part_msdos fat ext2 normal linux configfile \
    search search_fs_uuid echo gzio efi_gop
```

## 3. USB 부팅 디스크 레이아웃

```
/dev/sdX1  ESP   (FAT32, 512MB)  : /EFI/BOOT/BOOTAA64.EFI (=grub), grub.cfg, Image.gz, DTB
/dev/sdX2  root  (ext4, 나머지)  : Ubuntu ARM64 rootfs
```

`scripts/make-boot-usb.sh /dev/sdX` 가 파티셔닝부터 grub.cfg 생성까지 수행한다.

### grub.cfg 핵심 (ACPI 경로, bring-up용)

```
set timeout=3
menuentry "Ubuntu ARM64 (ACPI)" {
    search --no-floppy --fs-uuid --set=root <ESP-UUID>
    linux /Image.gz root=UUID=<ROOTFS-UUID> rw \
        console=tty0 console=ttyMSM0,115200 \
        clk_ignore_unused pd_ignore_unused \
        arm64.nopauth efi=noruntime
    # DT 경로 테스트 시 아래 줄 추가:
    # devicetree /sc8180xp-microsoft-surface-pro-x.dtb
}
```

커널 파라미터 근거:
- `clk_ignore_unused pd_ignore_unused` — qcom bring-up 필수. DT/드라이버가
  아직 참조하지 않는 클럭·파워도메인을 커널이 꺼버리면 디스플레이 등이 즉사함
- `efi=noruntime` — 일부 qcom UEFI 런타임 서비스 호출이 hang을 유발
- `arm64.nopauth` — 구형 펌웨어의 pointer auth 비호환 회피

## 4. 내장 NVMe로 이전 (USB 부팅 성공 후)

```
/dev/nvme0n1p1  EFI System Partition (FAT32, 512MB)
/dev/nvme0n1p2  Linux root (ext4)
```

Windows를 유지하려면 기존 ESP를 공유하고 C: 파티션만 축소한다.

```bash
sudo efibootmgr --create --disk /dev/nvme0n1 --part 1 \
    --label "Ubuntu ARM64" --loader '\EFI\ubuntu\grubaa64.efi'
```

## 5. 검증 체크리스트 (실기기 필요)

- [ ] Secure Boot off 상태에서 USB의 BOOTAA64.EFI가 실행되어 GRUB 메뉴 표시
- [ ] ACPI 모드로 커널이 earlycon 출력까지 도달
- [ ] rootfs 마운트, getty 로그인 프롬프트
- [ ] `devicetree` 라인 추가 시 DT 모드 부팅 (— #3 완료 후)

## 알려진 이슈

- NVMe 인식은 #4 선행 필요 → 그래서 USB rootfs로 시작
- 화면 출력이 없을 수 있음(efifb 미지원 시) → USB 시리얼 어댑터 또는
  부팅 후 SSH(USB 이더넷)로 확인하는 플랜 B 준비
