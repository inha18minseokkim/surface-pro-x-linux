# 커널 패치 (메인라인 / linux-surface 베이스 대비)

`NNNN-component-description.patch` 형식으로 번호를 붙여 적용 순서를 보장한다.

예정된 패치 시리즈:

| 번호대 | 컴포넌트 | 이슈 |
|--------|----------|------|
| 00xx | arm64/qcom 기반 (clk, pinctrl sc8180xp 대응) | #3 |
| 01xx | PCIe / NVMe quirk | #4 |
| 02xx | GPU (drm/msm Adreno 680 sc8180xp) | #5 |
| 03xx | ath11k (WCN3998) | #6 |
| 04xx | MHI pci_generic: SDX24 device id + 채널 설정 | #7 |
| 05xx | Surface Aggregator / Type Cover | #8 |

적용:

```bash
cd work/kernel
git am ../../patches/*.patch
```
