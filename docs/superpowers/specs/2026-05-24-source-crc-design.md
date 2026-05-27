# Step 1: 信源生成 + CRC-16 编码

## 文件

`source_crc.m`，放在 `vhf_ofdm/` 根目录

## 函数

### `bits = generate_source(n_bits)`
- 输入：总比特数 n_bits = 1,000,000
- 输出：bits (1 × n_bits double, 0/1)
- 实现：`randi([0,1], 1, n_bits)`

### `tx_bits = crc16_encode(data_bits, frame_len)`
- 输入：data_bits, frame_len (默认 1024)
- 输出：tx_bits (1 × total, 0/1)，包含所有帧的编码数据
- CRC-16-CCITT，多项式 `0x1021`，初始值 `0x0000`
- 每帧 1024 bit 数据 + 16 bit CRC = 1040 bit/帧
- 最后一帧不足时补零
- 总帧数 ≈ 977

## 输出

控制台打印：
- 总信源比特数
- 帧数
- 每帧长度（数据 + CRC）
- CRC 校验位总开销

## 不在本次范围
- 不画图
- 不含信道编码、交织等后续模块
- 不做 CRC 校验（接收端再做）
