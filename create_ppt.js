const pptxgen = require("pptxgenjs");
const React = require("react");
const ReactDOMServer = require("react-dom/server");
const sharp = require("sharp");

// Try to load icons, fallback gracefully
let FaCubes, FaLock, FaRandom, FaProjectDiagram, FaSignal, FaBroadcastTower;
let FaSatelliteDish, FaMicrochip, FaChartBar, FaServer, FaWifi, FaListUl;
try {
  const fa = require("react-icons/fa");
  FaCubes = fa.FaCubes;
  FaLock = fa.FaLock;
  FaRandom = fa.FaRandom;
  FaProjectDiagram = fa.FaProjectDiagram;
  FaSignal = fa.FaSignal;
  FaBroadcastTower = fa.FaBroadcastTower;
  FaSatelliteDish = fa.FaSatelliteDish;
  FaMicrochip = fa.FaMicrochip;
  FaChartBar = fa.FaChartBar;
  FaServer = fa.FaServer;
  FaWifi = fa.FaWifi;
  FaListUl = fa.FaListUl;
} catch (e) {
  console.warn("react-icons not available, skipping icons");
}

async function iconToBase64Png(IconComponent, color, size = 256) {
  if (!IconComponent) return null;
  try {
    const svg = ReactDOMServer.renderToStaticMarkup(
      React.createElement(IconComponent, { color, size: String(size) })
    );
    const pngBuffer = await sharp(Buffer.from(svg)).png().toBuffer();
    return "image/png;base64," + pngBuffer.toString("base64");
  } catch (e) {
    return null;
  }
}

async function main() {
  let pres = new pptxgen();
  pres.layout = "LAYOUT_16x9";
  pres.author = "Group 2";
  pres.title = "VHF OFDM无线通信系统仿真";

  // ============================================================
  // Color Palette
  // ============================================================
  const C = {
    bg: "0A1628",
    bgCard: "0F2744",
    bgCardLt: "132E50",
    title: "38BDF8",
    text: "E2E8F0",
    subtext: "94A3B8",
    accent: "0EA5E9",
    accent2: "06B6D4",
    txBlue: "2563EB",
    txBlueLt: "3B82F6",
    txBlueDk: "1D4ED8",
    channel: "EA580C",
    channelLt: "F97316",
    channelDk: "C2410C",
    rxGreen: "059669",
    rxGreenLt: "10B981",
    rxGreenDk: "047857",
    white: "FFFFFF",
    thBg: "1E3A5F",
    trOdd: "122B4A",
    trEven: "0F2540",
    border: "2D4A6F",
    borderLt: "3D5A7F",
    success: "22C55E",
    warning: "F59E0B",
    red: "EF4444",
    purple: "7C3AED",
    yellow: "EAB308",
  };

  // Pre-render icons
  const icons = {};
  if (FaCubes) {
    icons.cubes = await iconToBase64Png(FaCubes, "#38BDF8", 256);
    icons.lock = await iconToBase64Png(FaLock, "#38BDF8", 256);
    icons.random = await iconToBase64Png(FaRandom, "#38BDF8", 256);
    icons.project = await iconToBase64Png(FaProjectDiagram, "#38BDF8", 256);
    icons.signal = await iconToBase64Png(FaSignal, "#38BDF8", 256);
    icons.tower = await iconToBase64Png(FaBroadcastTower, "#EA580C", 256);
    icons.satellite = await iconToBase64Png(FaSatelliteDish, "#10B981", 256);
    icons.chip = await iconToBase64Png(FaMicrochip, "#38BDF8", 256);
    icons.chart = await iconToBase64Png(FaChartBar, "#22C55E", 256);
    icons.server = await iconToBase64Png(FaServer, "#38BDF8", 256);
    icons.wifi = await iconToBase64Png(FaWifi, "#38BDF8", 256);
    icons.list = await iconToBase64Png(FaListUl, "#94A3B8", 256);
  }

  // ============================================================
  // Helper Functions
  // ============================================================
  function addSlideNumber(slide, num) {
    slide.addText(String(num), {
      x: 0.15, y: 5.3, w: 0.35, h: 0.25,
      fontSize: 8, color: C.subtext, fontFace: "Calibri",
      align: "left", margin: 0,
    });
  }

  function addBackButton(slide, targetSlide = 2) {
    slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
      x: 8.1, y: 5.15, w: 1.6, h: 0.35,
      fill: { color: C.bgCard },
      line: { color: C.border, width: 0.5 },
      rectRadius: 0.05,
      hyperlink: { slide: targetSlide },
    });
    slide.addText("↩ 返回总览", {
      x: 8.1, y: 5.15, w: 1.6, h: 0.35,
      fontSize: 8, color: C.accent2, fontFace: "Calibri",
      align: "center", valign: "middle", margin: 0,
    });
  }

  function addTopBar(slide, title, subtitle) {
    slide.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0, w: 10, h: 0.03,
      fill: { color: C.accent },
    });
    slide.addShape(pres.shapes.RECTANGLE, {
      x: 0, y: 0.03, w: 10, h: 0.77,
      fill: { color: C.bgCard },
    });
    slide.addText(title, {
      x: 0.5, y: 0.08, w: 9, h: 0.45,
      fontSize: 22, color: C.title, fontFace: "Arial Black",
      bold: true, margin: 0,
    });
    if (subtitle) {
      slide.addText(subtitle, {
        x: 0.5, y: 0.5, w: 9, h: 0.28,
        fontSize: 10, color: C.subtext, fontFace: "Calibri", margin: 0,
      });
    }
  }

  // Card box helper
  function addCard(slide, x, y, w, h, color) {
    slide.addShape(pres.shapes.RECTANGLE, {
      x, y, w, h,
      fill: { color: color || C.bgCard },
      line: { color: C.border, width: 0.5 },
    });
    // Left accent strip
    slide.addShape(pres.shapes.RECTANGLE, {
      x, y, w: 0.04, h,
      fill: { color: C.accent },
    });
  }

  function makeShadow() {
    return { type: "outer", color: "000000", blur: 6, offset: 2, angle: 135, opacity: 0.2 };
  }

  // ============================================================
  // SLIDE 1: Title
  // ============================================================
  let s1 = pres.addSlide();
  s1.background = { color: "071326" };

  // Large decorative circles
  s1.addShape(pres.shapes.OVAL, {
    x: -1.5, y: -1.5, w: 5, h: 5,
    fill: { color: C.accent, transparency: 93 },
  });
  s1.addShape(pres.shapes.OVAL, {
    x: 7, y: 2.5, w: 4, h: 4,
    fill: { color: C.accent2, transparency: 90 },
  });
  s1.addShape(pres.shapes.OVAL, {
    x: 3, y: 4, w: 3, h: 3,
    fill: { color: C.txBlue, transparency: 92 },
  });

  // Tech line pattern in background
  for (let i = 0; i < 8; i++) {
    s1.addShape(pres.shapes.RECTANGLE, {
      x: 1.5 + i * 0.9, y: 1.5, w: 0.6, h: 0.005,
      fill: { color: C.border, transparency: 70 },
    });
  }

  // Central title area
  s1.addShape(pres.shapes.RECTANGLE, {
    x: 0.8, y: 1.0, w: 8.4, h: 3.6,
    fill: { color: C.bg, transparency: 30 },
  });
  s1.addShape(pres.shapes.LINE, {
    x: 1.8, y: 2.15, w: 6.4, h: 0,
    line: { color: C.accent, width: 1.5 },
  });
  s1.addShape(pres.shapes.LINE, {
    x: 1.8, y: 3.55, w: 6.4, h: 0,
    line: { color: C.accent, width: 0.5, dashType: "dash" },
  });

  // Title text
  s1.addText("VHF OFDM无线通信系统仿真", {
    x: 0.8, y: 1.2, w: 8.4, h: 0.95,
    fontSize: 36, color: C.white, fontFace: "Arial Black",
    bold: true, align: "center", valign: "middle", margin: 0,
  });

  s1.addText("移动通信课程设计", {
    x: 0.8, y: 2.35, w: 8.4, h: 0.7,
    fontSize: 22, color: C.accent, fontFace: "Calibri",
    align: "center", valign: "middle", margin: 0,
  });

  s1.addText([
    { text: "第2组", options: { bold: true, fontSize: 16, color: C.white } },
    { text: "  |  ", options: { color: C.subtext } },
    { text: "军用车载移动信道", options: { fontSize: 14, color: C.text } },
    { text: "  |  ", options: { color: C.subtext } },
    { text: "2026", options: { fontSize: 14, color: C.accent2 } },
  ], {
    x: 0.8, y: 3.7, w: 8.4, h: 0.5,
    align: "center", valign: "middle", margin: 0, fontFace: "Calibri",
  });

  // Corner diamonds
  [0.5, 9.5].forEach(cx => {
    [0.5, 5.125].forEach(cy => {
      s1.addShape(pres.shapes.RECTANGLE, {
        x: cx - 0.12, y: cy - 0.12, w: 0.24, h: 0.24,
        fill: { color: C.accent, transparency: 50 },
        rotate: 45,
      });
    });
  });

  // Bottom data-stream pattern
  for (let j = 0; j < 30; j++) {
    s1.addShape(pres.shapes.RECTANGLE, {
      x: 0.2 + j * 0.32, y: 5.35, w: 0.2, h: 0.015,
      fill: { color: C.accent, transparency: 80 },
    });
  }

  addSlideNumber(s1, 1);

  // ============================================================
  // SLIDE 2: System Block Diagram (Navigation Hub)
  // ============================================================
  let s2 = pres.addSlide();
  s2.background = { color: C.bg };
  addTopBar(s2, "系统框图 — 导航总览", "点击框图查看各模块详细说明");

  const bw = 1.2, bh = 0.6, gap = 0.1;
  const txBlocks = [
    { text: "信源", slide: 4 },
    { text: "CRC-16", slide: 4 },
    { text: "卷积编码", slide: 5 },
    { text: "交织", slide: 6 },
    { text: "符号调制", slide: 7 },
    { text: "OFDM调制", slide: 8 },
  ];
  const rxBlocks = [
    { text: "同步", slide: 13 },
    { text: "信道估计\n与均衡", slide: 13 },
    { text: "解调/解交织\n/译码", slide: 14 },
    { text: "BER统计", slide: 14 },
  ];

  const txStartX = 0.5;
  const txY = 1.25;
  const chanY = 2.35;
  const rxStartX = 0.75;
  const rxY = 3.55;

  // Draw TX blocks
  txBlocks.forEach((block, i) => {
    let bx = txStartX + i * (bw + gap);
    let col = i === txBlocks.length - 1 ? C.txBlueDk : C.txBlue;
    s2.addShape(pres.shapes.RECTANGLE, {
      x: bx, y: txY, w: bw, h: bh,
      fill: { color: col },
      line: { color: "60A5FA", width: 0.5 },
      shadow: makeShadow(),
    });
    s2.addText(block.text, {
      x: bx, y: txY, w: bw, h: bh - 0.16,
      fontSize: 8.5, color: C.white, fontFace: "Calibri",
      align: "center", valign: "middle", bold: true, margin: 0,
    });
    s2.addText("→ Slide " + block.slide, {
      x: bx, y: txY + bh - 0.18, w: bw, h: 0.16,
      fontSize: 5.5, color: "93C5FD", fontFace: "Calibri",
      align: "center", valign: "middle", margin: 0,
    });
    if (i < txBlocks.length - 1) {
      s2.addShape(pres.shapes.RECTANGLE, {
        x: bx + bw, y: txY + bh / 2 - 0.015, w: gap, h: 0.03,
        fill: { color: C.accent2 },
      });
      // arrowhead
      s2.addShape(pres.shapes.RECTANGLE, {
        x: bx + bw + gap - 0.04, y: txY + bh / 2 - 0.04, w: 0.04, h: 0.08,
        fill: { color: C.accent2 }, rotate: 0,
      });
    }
  });

  // VHF Channel block
  let chanX = 3.2, chanW = 3.6;
  s2.addShape(pres.shapes.RECTANGLE, {
    x: chanX, y: chanY, w: chanW, h: bh + 0.1,
    fill: { color: C.channel },
    line: { color: "FB923C", width: 0.8 },
    shadow: makeShadow(),
  });
  s2.addText("VHF 车载移动信道", {
    x: chanX, y: chanY, w: chanW, h: bh - 0.1,
    fontSize: 13, color: C.white, fontFace: "Calibri",
    align: "center", valign: "middle", bold: true, margin: 0,
  });
  s2.addText("→ Slide 12", {
    x: chanX, y: chanY + bh - 0.16, w: chanW, h: 0.16,
    fontSize: 6, color: "FED7AA", fontFace: "Calibri",
    align: "center", valign: "middle", margin: 0,
  });

  // Vertical connectors
  let txLastX = txStartX + 5 * (bw + gap) + bw / 2;
  let rxFirstX = rxBlocks.length > 0 ? rxStartX + 0 * (bw + gap + 0.45) + bw / 2 : 5;

  s2.addShape(pres.shapes.RECTANGLE, {
    x: txLastX - 0.015, y: txY + bh, w: 0.03, h: chanY - txY - bh,
    fill: { color: C.borderLt },
  });
  s2.addShape(pres.shapes.RECTANGLE, {
    x: rxFirstX - 0.015, y: chanY + bh + 0.1, w: 0.03, h: rxY - chanY - bh - 0.1,
    fill: { color: C.borderLt },
  });

  // Horizontal connector between vertical drops
  s2.addShape(pres.shapes.RECTANGLE, {
    x: txLastX, y: chanY - 0.1, w: rxFirstX - txLastX, h: 0.015,
    fill: { color: C.borderLt },
  });

  // Draw RX blocks
  rxBlocks.forEach((block, i) => {
    let bw2 = i === 2 ? bw + 0.25 : i === 0 ? bw - 0.1 : bw + 0.15;
    let bx = rxStartX + i * (bw2 + gap + 0.3);
    let col = C.rxGreen;
    s2.addShape(pres.shapes.RECTANGLE, {
      x: bx, y: rxY, w: bw2, h: bh + 0.05,
      fill: { color: col },
      line: { color: "34D399", width: 0.5 },
      shadow: makeShadow(),
    });
    s2.addText(block.text, {
      x: bx, y: rxY, w: bw2, h: bh - 0.1,
      fontSize: 7.5, color: C.white, fontFace: "Calibri",
      align: "center", valign: "middle", bold: true, margin: 0,
    });
    s2.addText("→ Slide " + block.slide, {
      x: bx, y: rxY + bh - 0.16, w: bw2, h: 0.16,
      fontSize: 5.5, color: "A7F3D0", fontFace: "Calibri",
      align: "center", valign: "middle", margin: 0,
    });
    if (i < rxBlocks.length - 1) {
      let nx = bx + bw2;
      s2.addShape(pres.shapes.RECTANGLE, {
        x: nx, y: rxY + (bh + 0.05) / 2 - 0.015, w: 0.3, h: 0.03,
        fill: { color: C.accent2 },
      });
    }
  });

  // Section labels on left side
  const sections = [
    { label: "发射端", y: txY, h: bh, color: C.txBlue },
    { label: "信道", y: chanY, h: bh + 0.1, color: C.channel },
    { label: "接收端", y: rxY, h: bh + 0.05, color: C.rxGreen },
  ];
  sections.forEach(sec => {
    s2.addShape(pres.shapes.RECTANGLE, {
      x: 0.03, y: sec.y, w: 0.3, h: sec.h,
      fill: { color: sec.color },
    });
    s2.addText(sec.label, {
      x: 0.03, y: sec.y, w: 0.3, h: sec.h,
      fontSize: 7, color: C.white, fontFace: "Calibri",
      align: "center", valign: "middle", bold: true, margin: 0,
    });
  });

  addSlideNumber(s2, 2);
  // Back to title
  s2.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: 8.1, y: 5.15, w: 1.6, h: 0.35,
    fill: { color: C.bgCard },
    line: { color: C.border, width: 0.5 },
    rectRadius: 0.05,
    hyperlink: { slide: 1 },
  });
  s2.addText("↩ 返回首页", {
    x: 8.1, y: 5.15, w: 1.6, h: 0.35,
    fontSize: 8, color: C.accent2, fontFace: "Calibri",
    align: "center", valign: "middle", margin: 0,
  });

  // ============================================================
  // SLIDE 3: System Parameters
  // ============================================================
  let s3 = pres.addSlide();
  s3.background = { color: C.bg };
  addTopBar(s3, "系统参数总览", "System Parameters Overview");

  const params = [
    ["信号带宽", "1 MHz"],
    ["载波频率", "100 MHz"],
    ["晶振稳定度", "0.1 ppm"],
    ["信道模型", "军用车载移动信道（Military Vehicular Mobile）"],
    ["车速", "60 km/h"],
    ["多径", "5-path, 时延 [0, 0.2, 0.5, 1.0, 2.0] μs, 功率 [0, -3, -6, -9, -12] dB"],
    ["FFT大小", "512"],
    ["活跃子载波", "400"],
    ["子载波间隔", "1.95 kHz"],
    ["CP长度", "8 samples (8 μs)"],
    ["符号时长", "520 μs"],
    ["调制方式", "QPSK / 16QAM / 64QAM（可切换）"],
  ];

  // Build table data with alternating row colors
  let tableData = params.map((row, idx) => [
    {
      text: row[0],
      options: {
        fill: { color: idx % 2 === 0 ? C.trOdd : C.trEven },
        color: C.text,
        bold: true,
        fontSize: 11,
        fontFace: "Calibri",
        align: "right",
      },
    },
    {
      text: row[1],
      options: {
        fill: { color: idx % 2 === 0 ? C.trOdd : C.trEven },
        color: C.text,
        fontSize: 11,
        fontFace: "Calibri",
        align: "left",
      },
    },
  ]);

  s3.addTable(tableData, {
    x: 0.6, y: 1.1, w: 5.5,
    colW: [2.0, 3.5],
    rowH: [0.33, 0.33, 0.33, 0.33, 0.33, 0.33, 0.33, 0.33, 0.33, 0.33, 0.33, 0.33],
    border: { pt: 0.5, color: C.border },
  });

  // Feature highlights on the right side
  addCard(s3, 6.5, 1.1, 3.0, 1.35, C.bgCardLt);
  s3.addText("⭐ 关键特性", {
    x: 6.7, y: 1.15, w: 2.6, h: 0.35,
    fontSize: 13, color: C.warning, fontFace: "Calibri", bold: true, margin: 0,
  });
  s3.addText([
    { text: "• 带宽 1 MHz，支持高速数据传输", options: { bullet: false, breakLine: true, fontSize: 9, color: C.text } },
    { text: "• 512-FFT OFDM，可抵抗多径干扰", options: { bullet: false, breakLine: true, fontSize: 9, color: C.text } },
    { text: "• M-QAM可切换，灵活调整速率", options: { bullet: false, breakLine: true, fontSize: 9, color: C.text } },
    { text: "• 军用车载信道，真实环境仿真", options: { bullet: false, fontSize: 9, color: C.text } },
  ], {
    x: 6.6, y: 1.5, w: 2.8, h: 0.9,
    fontFace: "Calibri", margin: 0,
  });

  addCard(s3, 6.5, 2.65, 3.0, 1.55, C.bgCardLt);
  s3.addText("🔍 设计说明", {
    x: 6.7, y: 2.7, w: 2.6, h: 0.35,
    fontSize: 13, color: C.accent, fontFace: "Calibri", bold: true, margin: 0,
  });
  s3.addText([
    { text: "• 1 MHz带宽适合VHF频段分配", options: { bullet: false, breakLine: true, fontSize: 9, color: C.text } },
    { text: "• 0.1 ppm晶振确保频偏在 10 Hz以内", options: { bullet: false, breakLine: true, fontSize: 9, color: C.text } },
    { text: "• CP长度 8 μs > 最大时延 2 μs", options: { bullet: false, breakLine: true, fontSize: 9, color: C.text } },
    { text: "• 60 km/h → 多普勒频移≈ 5.56 Hz", options: { bullet: false, breakLine: true, fontSize: 9, color: C.text } },
    { text: "• 慢衰落信道（相干时间 >>帧周期）", options: { bullet: false, fontSize: 9, color: C.text } },
  ], {
    x: 6.6, y: 3.05, w: 2.8, h: 1.1,
    fontFace: "Calibri", margin: 0,
  });

  addBackButton(s3);
  addSlideNumber(s3, 3);

  // ============================================================
  // SLIDE 4: Source & CRC-16
  // ============================================================
  let s4 = pres.addSlide();
  s4.background = { color: C.bg };
  addTopBar(s4, "信源生成与CRC-16编码", "均匀随机比特流 + CRC循环冗余校验");

  // Left Card: Source
  addCard(s4, 0.4, 1.1, 4.4, 3.9);
  s4.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 1.1, w: 4.4, h: 0.06,
    fill: { color: C.txBlue },
  });
  s4.addText("信源生成", {
    x: 0.7, y: 1.2, w: 3.8, h: 0.4,
    fontSize: 16, color: C.txBlueLt, fontFace: "Calibri", bold: true, margin: 0,
  });
  if (icons.server) {
    s4.addImage({ data: icons.server, x: 4.0, y: 1.2, w: 0.35, h: 0.35 });
  }

  s4.addText([
    { text: "类型：", options: { bold: true, color: C.white, fontSize: 12 } },
    { text: "均匀随机比特流（Uniform Random Bits）", options: { color: C.text, fontSize: 11 } },
  ], { x: 0.7, y: 1.7, w: 3.8, h: 0.3, fontFace: "Calibri", margin: 0 });

  s4.addText([
    { text: "长度：", options: { bold: true, color: C.white, fontSize: 12 } },
    { text: "N = 10,000 bits", options: { color: C.text, fontSize: 11 } },
  ], { x: 0.7, y: 2.05, w: 3.8, h: 0.3, fontFace: "Calibri", margin: 0 });

  // Visual: bit statistics
  s4.addText("比特统计：", {
    x: 0.7, y: 2.45, w: 3.8, h: 0.3,
    fontSize: 12, color: C.white, bold: true, fontFace: "Calibri", margin: 0,
  });

  // Bar chart-like visual
  let barY = 2.8;
  s4.addShape(pres.shapes.RECTANGLE, {
    x: 0.8, y: barY, w: 1.5, h: 0.7,
    fill: { color: C.txBlue },
  });
  s4.addText("0 bits\n~50%", {
    x: 0.8, y: barY, w: 1.5, h: 0.7,
    fontSize: 10, color: C.white, fontFace: "Calibri",
    align: "center", valign: "middle", margin: 0,
  });
  s4.addShape(pres.shapes.RECTANGLE, {
    x: 2.5, y: barY, w: 1.5, h: 0.7,
    fill: { color: C.accent },
  });
  s4.addText("1 bits\n~50%", {
    x: 2.5, y: barY, w: 1.5, h: 0.7,
    fontSize: 10, color: C.white, fontFace: "Calibri",
    align: "center", valign: "middle", margin: 0,
  });

  // Frame division info
  s4.addText([
    { text: "帧结构：", options: { bold: true, color: C.white, fontSize: 12 } },
    { text: "10帧 × (1024 data + 16 CRC) = 10,400 bits", options: { color: C.text, fontSize: 11 } },
  ], { x: 0.7, y: 3.7, w: 3.8, h: 0.3, fontFace: "Calibri", margin: 0 });

  s4.addText("冗余率：16/1024 ≈ 1.56%", {
    x: 0.7, y: 4.05, w: 3.8, h: 0.3,
    fontSize: 11, color: C.accent2, fontFace: "Calibri", bold: true, margin: 0,
  });

  // Right Card: CRC-16 Details
  addCard(s4, 5.2, 1.1, 4.4, 3.9);
  s4.addShape(pres.shapes.RECTANGLE, {
    x: 5.2, y: 1.1, w: 4.4, h: 0.06,
    fill: { color: C.accent2 },
  });
  s4.addText("CRC-16-CCITT编码", {
    x: 5.5, y: 1.2, w: 3.5, h: 0.4,
    fontSize: 16, color: C.accent2, fontFace: "Calibri", bold: true, margin: 0,
  });
  if (icons.lock) {
    s4.addImage({ data: icons.lock, x: 8.5, y: 1.2, w: 0.35, h: 0.35 });
  }

  // CRC parameters
  let crcParams = [
    ["生成多项式", "0x1021 (CRC-16-CCITT)"],
    ["初始值", "0x0000"],
    ["CRC长度", "16 bits"],
    ["数据/帧", "1024 bits"],
    ["总帧数", "10 帧"],
    ["总输入", "10,400 bits"],
  ];
  let crcTable = crcParams.map((row, idx) => [
    { text: row[0], options: { fill: { color: idx % 2 === 0 ? C.trOdd : C.trEven }, color: C.text, bold: true, fontSize: 10, fontFace: "Calibri", align: "right" } },
    { text: row[1], options: { fill: { color: idx % 2 === 0 ? C.trOdd : C.trEven }, color: C.text, fontSize: 10, fontFace: "Calibri", align: "left" } },
  ]);
  s4.addTable(crcTable, {
    x: 5.5, y: 1.75, w: 3.8,
    colW: [1.5, 2.3],
    rowH: [0.3, 0.3, 0.3, 0.3, 0.3, 0.3],
    border: { pt: 0.5, color: C.border },
  });

  // CRC frame visualization
  s4.addText("帧结构可视化：", {
    x: 5.5, y: 3.7, w: 3.8, h: 0.3,
    fontSize: 11, color: C.white, bold: true, fontFace: "Calibri", margin: 0,
  });
  s4.addShape(pres.shapes.RECTANGLE, {
    x: 5.5, y: 4.0, w: 2.6, h: 0.5,
    fill: { color: C.txBlue },
  });
  s4.addText("Data: 1024 bits", {
    x: 5.5, y: 4.0, w: 2.6, h: 0.5,
    fontSize: 10, color: C.white, fontFace: "Calibri",
    align: "center", valign: "middle", margin: 0,
  });
  s4.addShape(pres.shapes.RECTANGLE, {
    x: 8.2, y: 4.0, w: 1.1, h: 0.5,
    fill: { color: C.accent2 },
  });
  s4.addText("CRC\n16 bits", {
    x: 8.2, y: 4.0, w: 1.1, h: 0.5,
    fontSize: 8, color: C.white, fontFace: "Calibri",
    align: "center", valign: "middle", margin: 0,
  });

  addBackButton(s4);
  addSlideNumber(s4, 4);

  // ============================================================
  // SLIDE 5: Channel Coding - Convolutional Code
  // ============================================================
  let s5 = pres.addSlide();
  s5.background = { color: C.bg };
  addTopBar(s5, "信道编码 — 卷积码（Convolutional Code）", "K=7, R=1/2, 生成多项式 [171, 133]₈");

  // Left: Parameters
  addCard(s5, 0.4, 1.1, 4.4, 4.0);
  s5.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 1.1, w: 4.4, h: 0.06,
    fill: { color: C.purple },
  });
  s5.addText("编码参数", {
    x: 0.7, y: 1.2, w: 3.8, h: 0.4,
    fontSize: 16, color: C.purple, fontFace: "Calibri", bold: true, margin: 0,
  });

  let ccParams = [
    ["约束长度 K", "7"],
    ["码率 R", "1/2"],
    ["生成多项式", "g₀=171₈, g₁=133₈"],
    ["g₀二进制", "1111001"],
    ["g₁二进制", "1011011"],
    ["输入长度", "10,400 bits (10帧)"],
    ["输出长度", "20,800 bits"],
    ["译码算法", "维特比（Viterbi）硬判决"],
  ];
  let ccTable = ccParams.map((row, idx) => [
    { text: row[0], options: { fill: { color: idx % 2 === 0 ? C.trOdd : C.trEven }, color: C.text, bold: true, fontSize: 10, fontFace: "Calibri", align: "right" } },
    { text: row[1], options: { fill: { color: idx % 2 === 0 ? C.trOdd : C.trEven }, color: C.text, fontSize: 10, fontFace: "Calibri", align: "left" } },
  ]);
  s5.addTable(ccTable, {
    x: 0.7, y: 1.7, w: 3.8,
    colW: [1.8, 2.0],
    rowH: [0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3],
    border: { pt: 0.5, color: C.border },
  });

  // Right: Trellis visualization (simplified)
  addCard(s5, 5.2, 1.1, 4.4, 4.0);
  s5.addShape(pres.shapes.RECTANGLE, {
    x: 5.2, y: 1.1, w: 4.4, h: 0.06,
    fill: { color: C.purple },
  });
  s5.addText("笃纹结构示意图（Trellis）", {
    x: 5.5, y: 1.2, w: 3.8, h: 0.4,
    fontSize: 14, color: C.purple, fontFace: "Calibri", bold: true, margin: 0,
  });

  // Trellis diagram - state nodes
  const states = ["000", "001", "010", "011", "100", "101", "110", "111"];
  let ty = 1.8;
  states.forEach((s, i) => {
    let sy = ty + i * 0.28;
    [0, 1.0, 2.0, 3.0].forEach(t => {
      s5.addShape(pres.shapes.OVAL, {
        x: 5.7 + t, y: sy, w: 0.18, h: 0.18,
        fill: { color: C.bgCard },
        line: { color: C.purple, width: 0.5 },
      });
    });
    s5.addText(s, {
      x: 5.2, y: sy - 0.01, w: 0.45, h: 0.2,
      fontSize: 6.5, color: C.subtext, fontFace: "Calibri",
      align: "right", valign: "middle", margin: 0,
    });
  });

  // Trellis connections (simplified)
  for (let i = 0; i < 4; i++) {
    s5.addShape(pres.shapes.LINE, {
      x: 5.88 + i, y: ty + i * 2 * 0.28 + 0.09, w: 1.0, h: -0.5,
      line: { color: C.purple, width: 0.5 },
    });
    s5.addShape(pres.shapes.LINE, {
      x: 5.88 + i, y: ty + i * 2 * 0.28 + 0.09, w: 1.0, h: 0.5,
      line: { color: C.accent2, width: 0.5 },
    });
  }

  s5.addText([
    { text: "—— ", options: { color: C.purple, fontSize: 9 } },
    { text: "输入=0", options: { color: C.purple, fontSize: 9 } },
    { text: "    ", options: { color: C.text } },
    { text: "—— ", options: { color: C.accent2, fontSize: 9 } },
    { text: "输入=1", options: { color: C.accent2, fontSize: 9 } },
  ], {
    x: 5.5, y: 4.3, w: 3.8, h: 0.3,
    fontFace: "Calibri", margin: 0,
  });

  s5.addText("K=7，共 2⁶⁻¹ = 64个状态（图为 K=3简化示意）", {
    x: 5.5, y: 4.6, w: 3.8, h: 0.3,
    fontSize: 9, color: C.subtext, fontFace: "Calibri", italic: true, margin: 0,
  });

  addBackButton(s5);
  addSlideNumber(s5, 5);

  // ============================================================
  // SLIDE 6: Interleaving
  // ============================================================
  let s6 = pres.addSlide();
  s6.background = { color: C.bg };
  addTopBar(s6, "随机交织（Random Interleaving）", "将突发错误转化为随机孤立错误");

  // Left: Diagram
  addCard(s6, 0.4, 1.1, 4.8, 2.2);
  s6.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 1.1, w: 4.8, h: 0.06,
    fill: { color: C.warning },
  });
  s6.addText("交织过程可视化", {
    x: 0.7, y: 1.2, w: 4.2, h: 0.35,
    fontSize: 14, color: C.warning, fontFace: "Calibri", bold: true, margin: 0,
  });

  // Before interleaving - burst pattern
  s6.addText("交织前（突发错误）：", {
    x: 0.7, y: 1.6, w: 4.2, h: 0.25,
    fontSize: 10, color: C.text, fontFace: "Calibri", margin: 0,
  });
  // Visual burst pattern
  for (let i = 0; i < 20; i++) {
    let isErr = i >= 7 && i <= 12;
    s6.addShape(pres.shapes.RECTANGLE, {
      x: 0.7 + i * 0.21, y: 1.9, w: 0.19, h: 0.3,
      fill: { color: isErr ? C.red : C.txBlue },
    });
  }
  s6.addText("突发错误块（~200子载波）", {
    x: 2.3, y: 2.25, w: 2.5, h: 0.2,
    fontSize: 7, color: C.red, fontFace: "Calibri", align: "center", margin: 0,
  });

  // Arrow
  s6.addShape(pres.shapes.RECTANGLE, {
    x: 2.1, y: 2.5, w: 0.6, h: 0.03,
    fill: { color: C.warning },
  });
  s6.addText("↓ 随机重排 rng(42)", {
    x: 1.0, y: 2.55, w: 2.8, h: 0.25,
    fontSize: 9, color: C.warning, fontFace: "Calibri", align: "center", margin: 0,
  });

  // After interleaving - scattered
  s6.addText("交织后（随机孤立错误）：", {
    x: 0.7, y: 2.85, w: 4.2, h: 0.25,
    fontSize: 10, color: C.text, fontFace: "Calibri", margin: 0,
  });
  // Visual scattered
  for (let i = 0; i < 20; i++) {
    let isErr = [2, 7, 11, 15, 18].includes(i);
    s6.addShape(pres.shapes.RECTANGLE, {
      x: 0.7 + i * 0.21, y: 3.15, w: 0.19, h: 0.3,
      fill: { color: isErr ? C.red : C.rxGreen },
    });
  }

  // Right side: explanation
  addCard(s6, 5.6, 1.1, 4.0, 2.2);
  s6.addText("原理说明", {
    x: 5.8, y: 1.2, w: 3.6, h: 0.35,
    fontSize: 14, color: C.warning, fontFace: "Calibri", bold: true, margin: 0,
  });
  s6.addText([
    { text: "• 随机置换：", options: { bold: true, color: C.white, breakLine: true, fontSize: 10 } },
    { text: "    使用 rng(42) 固定种子，确保可重复性", options: { color: C.text, breakLine: true, fontSize: 10 } },
    { text: "• 全帧置换：", options: { bold: true, color: C.white, breakLine: true, fontSize: 10 } },
    { text: "    整个帧内跨位置随机交换", options: { color: C.text, breakLine: true, fontSize: 10 } },
    { text: "• 目的：", options: { bold: true, color: C.white, breakLine: true, fontSize: 10 } },
    { text: "    频率选择性衰落会导致连续子载波上的突发错误。交织后错误被打散，卷积码可以有效纠正。", options: { color: C.text, fontSize: 10 } },
  ], {
    x: 5.8, y: 1.6, w: 3.6, h: 1.7,
    fontFace: "Calibri", margin: 0,
  });

  // Bottom: Key parameters
  addCard(s6, 0.4, 3.6, 9.2, 1.2);
  s6.addText("关键参数", {
    x: 0.7, y: 3.65, w: 2.0, h: 0.3,
    fontSize: 12, color: C.white, bold: true, fontFace: "Calibri", margin: 0,
  });
  let intParams = [
    ["随机种子", "rng(42)", "可重复性"],
    ["置换范围", "全帧交织", "跨位置"],
    ["错误转化", "突发→随机孤立", "适配卷积码"],
  ];
  let intTable = intParams.map(row => [
    { text: row[0], options: { fill: { color: C.bgCard }, color: C.white, bold: true, fontSize: 10 } },
    { text: row[1], options: { fill: { color: C.bgCard }, color: C.text, fontSize: 10 } },
    { text: row[2], options: { fill: { color: C.bgCard }, color: C.subtext, fontSize: 9 } },
  ]);
  s6.addTable(intTable, {
    x: 0.7, y: 4.0, w: 8.6,
    colW: [2.2, 3.0, 3.4],
    border: { pt: 0.5, color: C.border },
  });

  addBackButton(s6);
  addSlideNumber(s6, 6);

  // ============================================================
  // SLIDE 7: Modulation
  // ============================================================
  let s7 = pres.addSlide();
  s7.background = { color: C.bg };
  addTopBar(s7, "符号调制 — QPSK / 16QAM / 64QAM", "支持三种调制方式可切换");

  const mods = [
    {
      name: "QPSK",
      color: C.txBlue,
      bps: 2,
      bitsPerSym: 800,
      desc: "4点星座，低 SNR下可靠",
      points: [[1, 1], [1, -1], [-1, 1], [-1, -1]],
    },
    {
      name: "16QAM",
      color: C.purple,
      bps: 4,
      bitsPerSym: 1600,
      desc: "16点星座，速率与可靠性平衡",
      points: [],
    },
    {
      name: "64QAM",
      color: C.accent,
      bps: 6,
      bitsPerSym: 2400,
      desc: "64点星座，高速率，需高 SNR",
      points: [],
    },
  ];

  mods.forEach((mod, idx) => {
    let cx = 0.5 + idx * 3.1;
    let cw = 2.9;

    // Card
    s7.addShape(pres.shapes.RECTANGLE, {
      x: cx, y: 1.15, w: cw, h: 4.0,
      fill: { color: C.bgCard },
      line: { color: mod.color, width: 0.8 },
      shadow: makeShadow(),
    });
    s7.addShape(pres.shapes.RECTANGLE, {
      x: cx, y: 1.15, w: cw, h: 0.06,
      fill: { color: mod.color },
    });

    // Name
    s7.addText(mod.name, {
      x: cx, y: 1.3, w: cw, h: 0.42,
      fontSize: 20, color: mod.color, fontFace: "Arial Black",
      bold: true, align: "center", valign: "middle", margin: 0,
    });

    // Constellation grid
    let gridX = cx + 0.25, gridY = 1.9, gridSize = 2.4, gridCenter = gridSize / 2;
    // Draw axes
    s7.addShape(pres.shapes.RECTANGLE, {
      x: gridX, y: gridY + gridCenter - 0.01, w: gridSize, h: 0.02,
      fill: { color: C.border },
    });
    s7.addShape(pres.shapes.RECTANGLE, {
      x: gridX + gridCenter - 0.01, y: gridY, w: 0.02, h: gridSize,
      fill: { color: C.border },
    });

    if (mod.name === "QPSK") {
      // 4 points
      const pts = [[1, 1], [-1, 1], [-1, -1], [1, -1]];
      pts.forEach(([px, py]) => {
        s7.addShape(pres.shapes.OVAL, {
          x: gridX + gridCenter + px * 0.7 - 0.08, y: gridY + gridCenter - py * 0.7 - 0.08, w: 0.16, h: 0.16,
          fill: { color: mod.color },
        });
      });
    } else if (mod.name === "16QAM") {
      for (let ri = -1.5; ri <= 1.5; ri += 1) {
        for (let ci = -1.5; ci <= 1.5; ci += 1) {
          if (ri !== 0 && ci !== 0) {
            s7.addShape(pres.shapes.OVAL, {
              x: gridX + gridCenter + ci * 0.55 - 0.07, y: gridY + gridCenter - ri * 0.55 - 0.07, w: 0.12, h: 0.12,
              fill: { color: mod.color },
            });
          }
        }
      }
    } else {
      // 64QAM - denser points
      for (let ri = -3.5; ri <= 3.5; ri += 1) {
        for (let ci = -3.5; ci <= 3.5; ci += 1) {
          s7.addShape(pres.shapes.OVAL, {
            x: gridX + gridCenter + ci * 0.22 - 0.04, y: gridY + gridCenter - ri * 0.22 - 0.04, w: 0.06, h: 0.06,
            fill: { color: mod.color },
          });
        }
      }
    }

    // Labels
    s7.addText("I", {
      x: gridX + gridSize - 0.15, y: gridY + gridCenter - 0.08, w: 0.2, h: 0.2,
      fontSize: 10, color: C.subtext, fontFace: "Calibri", margin: 0,
    });
    s7.addText("Q", {
      x: gridX + gridCenter - 0.08, y: gridY - 0.15, w: 0.2, h: 0.2,
      fontSize: 10, color: C.subtext, fontFace: "Calibri", margin: 0,
    });

    // Parameters
    s7.addText([
      { text: "bits/符号: ", options: { color: C.subtext, fontSize: 10 } },
      { text: String(mod.bps), options: { color: C.white, bold: true, fontSize: 10 } },
    ], {
      x: cx + 0.2, y: gridY + gridSize + 0.1, w: cw - 0.4, h: 0.25,
      fontFace: "Calibri", margin: 0,
    });
    s7.addText([
      { text: "bits/OFDM符号: ", options: { color: C.subtext, fontSize: 10 } },
      { text: String(mod.bitsPerSym), options: { color: C.white, bold: true, fontSize: 10 } },
    ], {
      x: cx + 0.2, y: gridY + gridSize + 0.35, w: cw - 0.4, h: 0.25,
      fontFace: "Calibri", margin: 0,
    });
    s7.addText(mod.desc, {
      x: cx + 0.2, y: gridY + gridSize + 0.65, w: cw - 0.4, h: 0.3,
      fontSize: 9, color: C.subtext, fontFace: "Calibri", margin: 0,
    });
  });

  addBackButton(s7);
  addSlideNumber(s7, 7);

  // ============================================================
  // SLIDE 8: OFDM Subcarrier Allocation
  // ============================================================
  let s8 = pres.addSlide();
  s8.background = { color: C.bg };
  addTopBar(s8, "OFDM子载波分配", "512-FFT 频域布局");

  // Visual spectrum layout
  let specX = 0.3, specY = 1.2, specW = 9.4, specH = 2.0;
  addCard(s8, specX, specY, specW, specH);

  s8.addText("Frequency Domain (512 bins)", {
    x: specX + 0.3, y: specY + 0.05, w: 5, h: 0.3,
    fontSize: 10, color: C.subtext, fontFace: "Calibri", margin: 0,
  });

  // Draw spectrum bars for each bin (sampled)
  let barW = specW / 512;
  for (let b = 0; b < 512; b++) {
    let fill;
    if (b === 0 || b === 256) {
      fill = C.channel; // DC, Nyquist
    } else if (b < 56) {
      fill = C.border; // Left guard
    } else if (b >= 57 && b <= 256) {
      fill = C.txBlue; // Data 1-200
    } else if (b >= 258 && b <= 457) {
      fill = C.rxGreen; // Data 201-400
    } else {
      fill = C.border; // Right guard
    }
    let barH = (b >= 57 && b <= 456) ? 1.2 : 0.6;
    s8.addShape(pres.shapes.RECTANGLE, {
      x: specX + 0.05 + b * barW * 0.85, y: specY + specH / 2 - barH / 2 + 0.1, w: barW * 0.8, h: barH,
      fill: { color: fill, transparency: fill === C.border ? 50 : 0 },
    });
  }

  // Section labels on the spectrum
  let sectionLabels = [
    { label: "DC = 0", x: 0, w: 0.5, color: C.channel },
    { label: "Guard\n(55)", x: 1, w: 2.5, color: C.subtext },
    { label: "Data 1-200", x: 3.5, w: 3.0, color: C.txBlue },
    { label: "Nyquist\n= 0", x: 6.8, w: 0.5, color: C.channel },
    { label: "Data 201-400", x: 7.3, w: 3.0, color: C.rxGreen },
    { label: "Guard\n(55)", x: 10.5, w: 2.5, color: C.subtext },
  ];

  // Bin index labels
  s8.addText("0", {
    x: specX + 0.05, y: specY + specH - 0.2, w: 0.4, h: 0.2,
    fontSize: 7, color: C.channel, fontFace: "Calibri", align: "center", margin: 0,
  });
  s8.addText("56", {
    x: specX + 0.05 + 56 * barW * 0.85 - 0.2, y: specY + specH - 0.2, w: 0.45, h: 0.2,
    fontSize: 7, color: C.subtext, fontFace: "Calibri", align: "center", margin: 0,
  });
  s8.addText("57", {
    x: specX + 0.05 + 57 * barW * 0.85 - 0.2, y: specY + specH - 0.2, w: 0.45, h: 0.2,
    fontSize: 7, color: C.txBlue, fontFace: "Calibri", align: "center", margin: 0,
  });
  s8.addText("256", {
    x: specX + 0.05 + 256 * barW * 0.85 - 0.2, y: specY + specH - 0.2, w: 0.45, h: 0.2,
    fontSize: 7, color: C.channel, fontFace: "Calibri", align: "center", margin: 0,
  });
  s8.addText("257", {
    x: specX + 0.05 + 257 * barW * 0.85 - 0.2, y: specY + specH - 0.2, w: 0.45, h: 0.2,
    fontSize: 7, color: C.channel, fontFace: "Calibri", align: "center", margin: 0,
  });
  s8.addText("457", {
    x: specX + 0.05 + 457 * barW * 0.85 - 0.2, y: specY + specH - 0.2, w: 0.45, h: 0.2,
    fontSize: 7, color: C.rxGreen, fontFace: "Calibri", align: "center", margin: 0,
  });

  // Summary table below
  addCard(s8, 0.3, 3.5, 9.4, 1.3);
  let allocParams = [
    ["Bins 1", "DC", "0", "避免DAC LO泄漏（本地振荡器）"],
    ["Bins 2-56", "左侧保护带（55）", "0", "抑制带外发射（sinc旁瓣）"],
    ["Bins 57-256", "数据 1-200", "QPSK/QAM", "200活跃子载波"],
    ["Bin 257", "Nyquist", "0", "奈奎斯特频率为零，避免混叠"],
    ["Bins 258-457", "数据 201-400", "QPSK/QAM", "200活跃子载波"],
    ["Bins 458-512", "右侧保护带（55）", "0", "抑制带外发射（sinc旁瓣）"],
  ];
  let allocTable = allocParams.map((row, idx) => [
    { text: row[0], options: { fill: { color: C.bgCard }, color: C.subtext, fontSize: 8 } },
    { text: row[1], options: { fill: { color: C.bgCard }, color: C.text, bold: true, fontSize: 9 } },
    { text: row[2], options: { fill: { color: C.bgCard }, color: C.subtext, fontSize: 8 } },
    { text: row[3], options: { fill: { color: C.bgCard }, color: C.text, fontSize: 8 } },
  ]);
  s8.addTable(allocTable, {
    x: 0.5, y: 3.6, w: 9.0,
    colW: [1.5, 2.5, 1.5, 3.5],
    border: { pt: 0.5, color: C.border },
  });

  addBackButton(s8);
  addSlideNumber(s8, 8);

  // ============================================================
  // SLIDE 9: OFDM Modulation - IFFT + CP
  // ============================================================
  let s9 = pres.addSlide();
  s9.background = { color: C.bg };
  addTopBar(s9, "OFDM调制 — IFFT + CP", "512点IFFT转换 + 循环前缀保护");

  // Left: IFFT explanation
  addCard(s9, 0.4, 1.1, 4.6, 3.9);
  s9.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 1.1, w: 4.6, h: 0.06,
    fill: { color: C.txBlue },
  });
  s9.addText("IFFT变换", {
    x: 0.7, y: 1.2, w: 4.0, h: 0.4,
    fontSize: 16, color: C.txBlueLt, fontFace: "Calibri", bold: true, margin: 0,
  });

  s9.addText([
    { text: "频域数据 X[k]，k=0..511 → 时域信号 x[n]", options: { color: C.text, fontSize: 11 } },
  ], { x: 0.7, y: 1.65, w: 4.0, h: 0.3, fontFace: "Calibri", margin: 0 });

  // IFFT diagram
  s9.addShape(pres.shapes.RECTANGLE, {
    x: 0.9, y: 2.1, w: 3.8, h: 0.65,
    fill: { color: C.txBlueDk },
    line: { color: C.txBlueLt, width: 0.5 },
  });
  s9.addText("512-point IFFT", {
    x: 0.9, y: 2.1, w: 3.8, h: 0.65,
    fontSize: 14, color: C.white, fontFace: "Calibri",
    align: "center", valign: "middle", bold: true, margin: 0,
  });

  s9.addText("→ 输出: 512点时域样本", {
    x: 0.7, y: 2.85, w: 4.0, h: 0.25,
    fontSize: 10, color: C.accent2, fontFace: "Calibri", margin: 0,
  });

  // Right: CP explanation
  addCard(s9, 5.3, 1.1, 4.3, 3.9);
  s9.addShape(pres.shapes.RECTANGLE, {
    x: 5.3, y: 1.1, w: 4.3, h: 0.06,
    fill: { color: C.warning },
  });
  s9.addText("循环前缀（CP）", {
    x: 5.6, y: 1.2, w: 3.7, h: 0.4,
    fontSize: 16, color: C.warning, fontFace: "Calibri", bold: true, margin: 0,
  });

  // CP visual
  s9.addShape(pres.shapes.RECTANGLE, {
    x: 5.6, y: 1.9, w: 1.2, h: 0.55,
    fill: { color: C.channel },
  });
  s9.addText("CP\n(8样本)", {
    x: 5.6, y: 1.9, w: 1.2, h: 0.55,
    fontSize: 8, color: C.white, fontFace: "Calibri",
    align: "center", valign: "middle", margin: 0,
  });
  s9.addShape(pres.shapes.RECTANGLE, {
    x: 6.9, y: 1.9, w: 2.3, h: 0.55,
    fill: { color: C.txBlue },
  });
  s9.addText("IFFT Body (512样本)", {
    x: 6.9, y: 1.9, w: 2.3, h: 0.55,
    fontSize: 9, color: C.white, fontFace: "Calibri",
    align: "center", valign: "middle", margin: 0,
  });

  // Arrow showing copy
  s9.addText("← 复制尾部8样本到前端", {
    x: 5.6, y: 2.5, w: 3.7, h: 0.25,
    fontSize: 8, color: C.channelLt, fontFace: "Calibri", italic: true, margin: 0,
  });

  // Key parameters
  s9.addText("关键参数：", {
    x: 5.6, y: 2.85, w: 3.7, h: 0.25,
    fontSize: 12, color: C.white, bold: true, fontFace: "Calibri", margin: 0,
  });
  s9.addText([
    { text: "• 总符号长度: 8 + 512 = 520样本", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "• 符号时长: 520 μs (样率 1 MHz)", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "• CP = 8 μs > 最大时延 2 μs", options: { breakLine: true, fontSize: 10, color: C.success } },
    { text: "• CP消除符号间干扰（ISI）", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "• 代价: 频谱效率 = 512/520 ≈ 98.5%", options: { fontSize: 10, color: C.subtext } },
  ], {
    x: 5.6, y: 3.15, w: 3.7, h: 1.8,
    fontFace: "Calibri", margin: 0,
  });

  // Bottom visual: time-domain symbol structure
  s9.addShape(pres.shapes.RECTANGLE, {
    x: 0.7, y: 3.5, w: 1.5, h: 0.5,
    fill: { color: C.channel },
  });
  s9.addText("CP(8)", {
    x: 0.7, y: 3.5, w: 1.5, h: 0.5,
    fontSize: 10, color: C.white, fontFace: "Calibri",
    align: "center", valign: "middle", bold: true, margin: 0,
  });
  s9.addShape(pres.shapes.RECTANGLE, {
    x: 2.3, y: 3.5, w: 2.4, h: 0.5,
    fill: { color: C.txBlue },
  });
  s9.addText("IFFT Body (512 = 512 μs)", {
    x: 2.3, y: 3.5, w: 2.4, h: 0.5,
    fontSize: 9, color: C.white, fontFace: "Calibri",
    align: "center", valign: "middle", margin: 0,
  });
  s9.addText("总长 = 520 μs →", {
    x: 0.45, y: 4.05, w: 4.5, h: 0.25,
    fontSize: 9, color: C.subtext, fontFace: "Calibri", margin: 0,
  });

  addBackButton(s9);
  addSlideNumber(s9, 9);

  // ============================================================
  // SLIDE 10: Training & Pilot
  // ============================================================
  let s10 = pres.addSlide();
  s10.background = { color: C.bg };
  addTopBar(s10, "训练序列与导频设计", "Training Sequence & Pilot Design");

  // Frame structure visual
  addCard(s10, 0.4, 1.1, 9.2, 1.5);
  s10.addText("帧结构：", {
    x: 0.6, y: 1.15, w: 2, h: 0.3,
    fontSize: 13, color: C.white, bold: true, fontFace: "Calibri", margin: 0,
  });

  let frameBlocks = [
    { label: "Training", color: C.warning, w: 1.8 },
    { label: "Pilot", color: C.accent, w: 1.8 },
    { label: "Data 1", color: C.txBlue, w: 1.4 },
    { label: "Data 2", color: C.txBlueLt, w: 1.4 },
    { label: "Data 3", color: C.txBlue, w: 1.4 },
    { label: "...", color: C.border, w: 0.8 },
  ];
  let fx = 0.6;
  frameBlocks.forEach(blk => {
    s10.addShape(pres.shapes.RECTANGLE, {
      x: fx, y: 1.55, w: blk.w - 0.05, h: 0.65,
      fill: { color: blk.color },
    });
    s10.addText(blk.label, {
      x: fx, y: 1.55, w: blk.w - 0.05, h: 0.65,
      fontSize: 9, color: C.white, fontFace: "Calibri",
      align: "center", valign: "middle", bold: true, margin: 0,
    });
    fx += blk.w;
  });

  // Note: each has CP (omitted for visual clarity)
  s10.addText("每个符号均包含 CP 前缀", {
    x: 0.6, y: 2.25, w: 5, h: 0.25,
    fontSize: 9, color: C.subtext, fontFace: "Calibri", italic: true, margin: 0,
  });

  // Left card: Training sequence
  addCard(s10, 0.4, 2.9, 4.5, 2.1);
  s10.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 2.9, w: 4.5, h: 0.06,
    fill: { color: C.warning },
  });
  s10.addText("训练序列（Training）", {
    x: 0.7, y: 3.0, w: 3.8, h: 0.35,
    fontSize: 14, color: C.warning, fontFace: "Calibri", bold: true, margin: 0,
  });
  s10.addText([
    { text: "• 类型：", options: { bold: true, color: C.white, fontSize: 10 } },
    { text: "PN序列（伪随机噪声）", options: { color: C.text, fontSize: 10 } },
  ], { x: 0.7, y: 3.4, w: 3.8, h: 0.25, fontFace: "Calibri", margin: 0 });
  s10.addText([
    { text: "• 种子：", options: { bold: true, color: C.white, fontSize: 10 } },
    { text: "rng seed = 7", options: { color: C.text, fontSize: 10 } },
  ], { x: 0.7, y: 3.65, w: 3.8, h: 0.25, fontFace: "Calibri", margin: 0 });
  s10.addText([
    { text: "• 用途：", options: { bold: true, color: C.white, fontSize: 10 } },
  ], { x: 0.7, y: 3.9, w: 3.8, h: 0.25, fontFace: "Calibri", margin: 0 });
  s10.addText([
    { text: "  - 时间同步：互相关峰值检测", options: { breakLine: true, fontSize: 9, color: C.text } },
    { text: "  - 频率同步：相位差分估计频偏", options: { breakLine: true, fontSize: 9, color: C.text } },
    { text: "  - 自相关特性好，互相关峰值明显", options: { fontSize: 9, color: C.text } },
  ], { x: 0.7, y: 4.15, w: 3.8, h: 0.8, fontFace: "Calibri", margin: 0 });

  // Right card: Pilot
  addCard(s10, 5.2, 2.9, 4.4, 2.1);
  s10.addShape(pres.shapes.RECTANGLE, {
    x: 5.2, y: 2.9, w: 4.4, h: 0.06,
    fill: { color: C.accent },
  });
  s10.addText("导频序列（Pilot）", {
    x: 5.5, y: 3.0, w: 3.7, h: 0.35,
    fontSize: 14, color: C.accent, fontFace: "Calibri", bold: true, margin: 0,
  });
  s10.addText([
    { text: "• 类型：", options: { bold: true, color: C.white, fontSize: 10 } },
    { text: "BPSK已知序列（块型导频）", options: { color: C.text, fontSize: 10 } },
  ], { x: 5.5, y: 3.4, w: 3.7, h: 0.25, fontFace: "Calibri", margin: 0 });
  s10.addText([
    { text: "• 种子：", options: { bold: true, color: C.white, fontSize: 10 } },
    { text: "rng seed = 13", options: { color: C.text, fontSize: 10 } },
  ], { x: 5.5, y: 3.65, w: 3.7, h: 0.25, fontFace: "Calibri", margin: 0 });
  s10.addText([
    { text: "• 用途：", options: { bold: true, color: C.white, fontSize: 10 } },
    { text: "信道估计（Channel Estimation）", options: { color: C.text, fontSize: 10 } },
  ], { x: 5.5, y: 3.9, w: 3.7, h: 0.25, fontFace: "Calibri", margin: 0 });
  s10.addText([
    { text: "• 覆盖范围：", options: { bold: true, color: C.white, fontSize: 10 } },
    { text: "全部 400个活跃子载波", options: { color: C.text, fontSize: 10 } },
  ], { x: 5.5, y: 4.15, w: 3.7, h: 0.25, fontFace: "Calibri", margin: 0 });

  s10.addShape(pres.shapes.RECTANGLE, {
    x: 5.5, y: 4.5, w: 3.7, h: 0.38,
    fill: { color: C.accent, transparency: 70 },
  });
  s10.addText("Ĥ_k = Y_k / X_k  (X_k = ±1, ZF估计)", {
    x: 5.5, y: 4.5, w: 3.7, h: 0.38,
    fontSize: 10, color: C.white, fontFace: "Calibri",
    align: "center", valign: "middle", margin: 0,
  });

  addBackButton(s10);
  addSlideNumber(s10, 10);

  // ============================================================
  // SLIDE 11: Frame Structure
  // ============================================================
  let s11 = pres.addSlide();
  s11.background = { color: C.bg };
  addTopBar(s11, "OFDM帧结构与符号数量", "不同调制方式下的帧组织");

  // Big table
  let frameData = [
    [
      { text: "调制方式", options: { fill: { color: C.thBg }, color: C.title, bold: true, fontSize: 12, fontFace: "Calibri" } },
      { text: "数据符号/帧", options: { fill: { color: C.thBg }, color: C.title, bold: true, fontSize: 12, fontFace: "Calibri" } },
      { text: "总符号数", options: { fill: { color: C.thBg }, color: C.title, bold: true, fontSize: 12, fontFace: "Calibri" } },
      { text: "帧时长", options: { fill: { color: C.thBg }, color: C.title, bold: true, fontSize: 12, fontFace: "Calibri" } },
      { text: "有效数据率", options: { fill: { color: C.thBg }, color: C.title, bold: true, fontSize: 12, fontFace: "Calibri" } },
    ],
    [
      { text: "QPSK", options: { fill: { color: C.trOdd }, color: C.txBlueLt, bold: true, fontSize: 13 } },
      { text: "26", options: { fill: { color: C.trOdd }, color: C.text, fontSize: 12 } },
      { text: "28 (1T+1P+26D)", options: { fill: { color: C.trOdd }, color: C.text, fontSize: 11 } },
      { text: "28 × 520 μs = 14.56 ms", options: { fill: { color: C.trOdd }, color: C.text, fontSize: 11 } },
      { text: "26/28 = 92.9%", options: { fill: { color: C.trOdd }, color: C.success, fontSize: 11 } },
    ],
    [
      { text: "16QAM", options: { fill: { color: C.trEven }, color: C.purple, bold: true, fontSize: 13 } },
      { text: "13", options: { fill: { color: C.trEven }, color: C.text, fontSize: 12 } },
      { text: "15 (1T+1P+13D)", options: { fill: { color: C.trEven }, color: C.text, fontSize: 11 } },
      { text: "15 × 520 μs = 7.8 ms", options: { fill: { color: C.trEven }, color: C.text, fontSize: 11 } },
      { text: "13/15 = 86.7%", options: { fill: { color: C.trEven }, color: C.warning, fontSize: 11 } },
    ],
    [
      { text: "64QAM", options: { fill: { color: C.trOdd }, color: C.accent, bold: true, fontSize: 13 } },
      { text: "9", options: { fill: { color: C.trOdd }, color: C.text, fontSize: 12 } },
      { text: "11 (1T+1P+9D)", options: { fill: { color: C.trOdd }, color: C.text, fontSize: 11 } },
      { text: "11 × 520 μs = 5.72 ms", options: { fill: { color: C.trOdd }, color: C.text, fontSize: 11 } },
      { text: "9/11 = 81.8%", options: { fill: { color: C.trOdd }, color: C.channelLt, fontSize: 11 } },
    ],
  ];

  s11.addTable(frameData, {
    x: 0.5, y: 1.2, w: 9.0,
    colW: [1.5, 1.8, 2.5, 2.6, 1.6],
    border: { pt: 0.5, color: C.border },
  });

  // Analysis cards below
  addCard(s11, 0.5, 3.2, 4.3, 1.7);
  s11.addShape(pres.shapes.RECTANGLE, {
    x: 0.5, y: 3.2, w: 4.3, h: 0.06,
    fill: { color: C.txBlue },
  });
  s11.addText("设计说明", {
    x: 0.7, y: 3.3, w: 3.8, h: 0.3,
    fontSize: 13, color: C.txBlueLt, fontFace: "Calibri", bold: true, margin: 0,
  });
  s11.addText([
    { text: "• 每帧 = 1 Training + 1 Pilot + N个数据符号", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "• 训练和导频各占一个 OFDM符号", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "• 数据符号数取决于 bits/符号与总bits", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "• 帧时长 << 相干时间 (~0.18 s) → 慢衰落", options: { fontSize: 10, color: C.success } },
  ], {
    x: 0.7, y: 3.65, w: 3.8, h: 1.2,
    fontFace: "Calibri", margin: 0,
  });

  // Visual: frame composition for QPSK
  addCard(s11, 5.2, 3.2, 4.3, 1.7);
  s11.addShape(pres.shapes.RECTANGLE, {
    x: 5.2, y: 3.2, w: 4.3, h: 0.06,
    fill: { color: C.accent },
  });
  s11.addText("QPSK帧可视化（28符号）", {
    x: 5.4, y: 3.3, w: 3.8, h: 0.3,
    fontSize: 11, color: C.accent, fontFace: "Calibri", bold: true, margin: 0,
  });
  // Mini block diagram
  let miniBlocks = [
    { label: "T", color: C.warning, w: 0.45 },
    { label: "P", color: C.accent, w: 0.45 },
    { label: "D1...D26", color: C.txBlue, w: 2.5 },
  ];
  let mfx = 5.6;
  miniBlocks.forEach(mb => {
    s11.addShape(pres.shapes.RECTANGLE, {
      x: mfx, y: 3.85, w: mb.w - 0.03, h: 0.5,
      fill: { color: mb.color },
    });
    s11.addText(mb.label, {
      x: mfx, y: 3.85, w: mb.w - 0.03, h: 0.5,
      fontSize: 8, color: C.white, fontFace: "Calibri",
      align: "center", valign: "middle", margin: 0,
    });
    mfx += mb.w;
  });
  s11.addText("总时长: 28 × 520 μs = 14.56 ms", {
    x: 5.4, y: 4.45, w: 3.8, h: 0.25,
    fontSize: 10, color: C.text, fontFace: "Calibri", margin: 0,
  });

  addBackButton(s11);
  addSlideNumber(s11, 11);

  // ============================================================
  // SLIDE 12: VHF Channel Model
  // ============================================================
  let s12 = pres.addSlide();
  s12.background = { color: C.bg };
  addTopBar(s12, "VHF车载移动信道模型", "5-path Rayleigh Fading + Doppler + Fractional Delay");

  // Channel parameters table
  let chanParams = [
    ["多径数量", "5-path"],
    ["时延剖面（μs）", "[0, 0.2, 0.5, 1.0, 2.0]"],
    ["功率剖面（dB）", "[0, -3, -6, -9, -12]"],
    ["衰落类型", "Rayleigh（微小没有直射径）"],
    ["多普勒频移 fd", "5.56 Hz (60 km/h @ 100 MHz)"],
    ["相干时间 Tc", "≈ 0.18 s (1/fd)"],
    ["相干带宽 Bc", "≈ 390 kHz"],
    ["衰落类型", "慢衰落（Tc >> 帧时长 ~14.56 ms）"],
    ["频率选择性", "是（Bc < 信号带宽 1 MHz）"],
  ];

  let chanTable = chanParams.map((row, idx) => [
    { text: row[0], options: { fill: { color: idx % 2 === 0 ? C.trOdd : C.trEven }, color: C.text, bold: true, fontSize: 10, fontFace: "Calibri", align: "right" } },
    { text: row[1], options: { fill: { color: idx % 2 === 0 ? C.trOdd : C.trEven }, color: C.text, fontSize: 10, fontFace: "Calibri", align: "left" } },
  ]);

  s12.addTable(chanTable, {
    x: 0.5, y: 1.1, w: 5.2,
    colW: [2.2, 3.0],
    border: { pt: 0.5, color: C.border },
  });

  // Right side: Power Delay Profile visual
  addCard(s12, 6.0, 1.1, 3.6, 2.0);
  s12.addShape(pres.shapes.RECTANGLE, {
    x: 6.0, y: 1.1, w: 3.6, h: 0.06,
    fill: { color: C.channel },
  });
  s12.addText("功率时延剖面", {
    x: 6.2, y: 1.2, w: 3.2, h: 0.3,
    fontSize: 12, color: C.channelLt, fontFace: "Calibri", bold: true, margin: 0,
  });

  // PDP bars
  let pdpData = [[0, 0], [0.2, -3], [0.5, -6], [1.0, -9], [2.0, -12]];
  let pdpMaxH = 1.0;
  pdpData.forEach(([del, pwr]) => {
    let barH = (1 + pwr / 15) * pdpMaxH;
    let barX = 6.3 + del * 1.4;
    s12.addShape(pres.shapes.RECTANGLE, {
      x: barX, y: 1.7 + pdpMaxH - barH, w: 0.35, h: barH,
      fill: { color: C.channel },
    });
    s12.addText(String(pwr) + " dB", {
      x: barX - 0.1, y: 1.7 + pdpMaxH - barH - 0.2, w: 0.55, h: 0.18,
      fontSize: 7, color: C.subtext, fontFace: "Calibri", align: "center", margin: 0,
    });
    s12.addText(String(del) + " μs", {
      x: barX - 0.1, y: 2.78, w: 0.55, h: 0.2,
      fontSize: 7, color: C.subtext, fontFace: "Calibri", align: "center", margin: 0,
    });
  });

  // Implementation note
  addCard(s12, 6.0, 3.35, 3.6, 1.35);
  s12.addShape(pres.shapes.RECTANGLE, {
    x: 6.0, y: 3.35, w: 3.6, h: 0.06,
    fill: { color: C.accent2 },
  });
  s12.addText("实现方法", {
    x: 6.2, y: 3.45, w: 3.2, h: 0.3,
    fontSize: 12, color: C.accent2, fontFace: "Calibri", bold: true, margin: 0,
  });
  s12.addText([
    { text: "• Jakes Doppler谱：滤波高斯噪声法", options: { breakLine: true, fontSize: 9, color: C.text } },
    { text: "• 分数时延：interp1插值实现", options: { breakLine: true, fontSize: 9, color: C.text } },
    { text: "• 慢衰落近似：一帧内信道不变", options: { breakLine: true, fontSize: 9, color: C.text } },
    { text: "• 频率选择性：每子载波独立衰落", options: { fontSize: 9, color: C.text } },
  ], {
    x: 6.2, y: 3.8, w: 3.2, h: 0.85,
    fontFace: "Calibri", margin: 0,
  });

  // Bottom: Channel characteristics summary
  addCard(s12, 0.5, 3.35, 5.2, 1.35);
  s12.addShape(pres.shapes.RECTANGLE, {
    x: 0.5, y: 3.35, w: 5.2, h: 0.06,
    fill: { color: C.rxGreen },
  });
  s12.addText("信道特性总结", {
    x: 0.7, y: 3.45, w: 3.0, h: 0.3,
    fontSize: 12, color: C.rxGreenLt, fontFace: "Calibri", bold: true, margin: 0,
  });
  s12.addText([
    { text: "✓ 慢衰落：帧内信道恒定，可用块型导频", options: { breakLine: true, fontSize: 10, color: C.success } },
    { text: "✓ 频率选择性：需要 OFDM + 频域均衡", options: { breakLine: true, fontSize: 10, color: C.warning } },
    { text: "✓ 5径 Rayleigh：无直射径，实际场景仿真", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "✓ 多普勒 fd=5.56 Hz：低速移动性弱", options: { fontSize: 10, color: C.text } },
  ], {
    x: 0.7, y: 3.8, w: 4.8, h: 0.9,
    fontFace: "Calibri", margin: 0,
  });

  addBackButton(s12);
  addSlideNumber(s12, 12);

  // ============================================================
  // SLIDE 13: Receiver Sync & Channel Estimation
  // ============================================================
  let s13 = pres.addSlide();
  s13.background = { color: C.bg };
  addTopBar(s13, "接收端同步与信道估计", "Time Sync + Frequency Sync + Channel Estimation");

  // Left: Time & Frequency Sync
  addCard(s13, 0.4, 1.1, 4.6, 4.0);
  s13.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 1.1, w: 4.6, h: 0.06,
    fill: { color: C.warning },
  });
  s13.addText("时间同步（Time Sync）", {
    x: 0.7, y: 1.2, w: 4.0, h: 0.35,
    fontSize: 14, color: C.warning, fontFace: "Calibri", bold: true, margin: 0,
  });
  s13.addText([
    { text: "• 方法：已知训练序列与接收信号互相关", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "• 相关峰值位置 → 符号起始位置", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "• PN序列自相关特性好，峰值明显", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "• 精度：样本级别对齐", options: { fontSize: 10, color: C.text } },
  ], {
    x: 0.7, y: 1.65, w: 4.0, h: 1.0,
    fontFace: "Calibri", margin: 0,
  });

  s13.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 2.8, w: 4.6, h: 0.005,
    fill: { color: C.border },
  });

  s13.addText("频率同步（Freq Sync）", {
    x: 0.7, y: 2.95, w: 4.0, h: 0.35,
    fontSize: 14, color: C.warning, fontFace: "Calibri", bold: true, margin: 0,
  });
  s13.addText([
    { text: "• 方法：CP自相关法", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "• CP与IFFT尾部相同 → 相关峰值", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "• 相位差 → 频偏估计 Δf̂", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "• 补偿：时域乘复指数旋转", options: { fontSize: 10, color: C.text } },
  ], {
    x: 0.7, y: 3.4, w: 4.0, h: 0.9,
    fontFace: "Calibri", margin: 0,
  });

  s13.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 4.4, w: 4.6, h: 0.005,
    fill: { color: C.border },
  });

  // Right: Channel Estimation
  addCard(s13, 5.3, 1.1, 4.3, 4.0);
  s13.addShape(pres.shapes.RECTANGLE, {
    x: 5.3, y: 1.1, w: 4.3, h: 0.06,
    fill: { color: C.accent },
  });
  s13.addText("信道估计与均衡", {
    x: 5.6, y: 1.2, w: 3.7, h: 0.35,
    fontSize: 14, color: C.accent, fontFace: "Calibri", bold: true, margin: 0,
  });

  s13.addText("块型导频估计（Block-type Pilot）", {
    x: 5.6, y: 1.65, w: 3.7, h: 0.3,
    fontSize: 11, color: C.white, fontFace: "Calibri", bold: true, margin: 0,
  });

  // Estimation equation
  s13.addShape(pres.shapes.RECTANGLE, {
    x: 5.6, y: 2.05, w: 3.7, h: 0.5,
    fill: { color: C.bgCardLt },
  });
  s13.addText("Ĥ_k = Y_k / X_k   (ZF估计)", {
    x: 5.6, y: 2.05, w: 3.7, h: 0.5,
    fontSize: 12, color: C.accent, fontFace: "Calibri",
    align: "center", valign: "middle", bold: true, margin: 0,
  });

  s13.addText([
    { text: "• X_k = ±1 (BPSK已知导频)", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "• 覆盖全部 400个活跃子载波", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "• 慢衰落下，一帧使用同一估计值", options: { breakLine: true, fontSize: 10, color: C.text } },
  ], {
    x: 5.6, y: 2.65, w: 3.7, h: 0.8,
    fontFace: "Calibri", margin: 0,
  });

  // Equalization
  s13.addText("频域均衡（ZF Equalization）", {
    x: 5.6, y: 3.45, w: 3.7, h: 0.3,
    fontSize: 11, color: C.white, fontFace: "Calibri", bold: true, margin: 0,
  });
  s13.addShape(pres.shapes.RECTANGLE, {
    x: 5.6, y: 3.8, w: 3.7, h: 0.45,
    fill: { color: C.bgCardLt },
  });
  s13.addText("X̂_k = Y_k / Ĥ_k", {
    x: 5.6, y: 3.8, w: 3.7, h: 0.45,
    fontSize: 12, color: C.accent, fontFace: "Calibri",
    align: "center", valign: "middle", bold: true, margin: 0,
  });
  s13.addText([
    { text: "• 简单高效，但噪声放大在深衰落处", options: { breakLine: true, fontSize: 10, color: C.text } },
    { text: "• 可升级为 MMSE均衡以改善性能", options: { fontSize: 10, color: C.text } },
  ], {
    x: 5.6, y: 4.35, w: 3.7, h: 0.6,
    fontFace: "Calibri", margin: 0,
  });

  addBackButton(s13);
  addSlideNumber(s13, 13);

  // ============================================================
  // SLIDE 14: Receiver Decoding Chain
  // ============================================================
  let s14 = pres.addSlide();
  s14.background = { color: C.bg };
  addTopBar(s14, "接收端解码流程", "从接收信号到BER统计的完整链路");

  // Left: Flow diagram
  const rxFlow = [
    { label: "RX Signal", color: C.rxGreenDk, desc: "接收信号" },
    { label: "Remove CP", color: C.rxGreen, desc: "去除前缀8样本" },
    { label: "FFT", color: C.txBlue, desc: "512点FFT" },
    { label: "Equalize", color: C.accent, desc: "ZF均衡" },
    { label: "Demodulate", color: C.purple, desc: "硬判决解调" },
    { label: "Deinterleave", color: C.warning, desc: "反置换恢复顺序" },
    { label: "Viterbi", color: C.accent2, desc: "维特比译码" },
    { label: "CRC Check", color: C.success, desc: "校验过/失败" },
    { label: "BER Stats", color: C.red, desc: "比特错误率" },
  ];

  // Flow arrows - vertical layout in 2 columns
  let flowX1 = 0.6, flowX2 = 5.0, flowW = 2.0, flowH = 0.28, flowGap = 0.08;
  rxFlow.forEach((step, i) => {
    let col = i < 5 ? 0 : 1;
    let ri = i < 5 ? i : i - 5;
    let fx = col === 0 ? flowX1 : flowX2;
    let fy = 1.15 + ri * (flowH + flowGap + 0.05);

    if (col === 0) flowW = 2.2;
    else flowW = 2.5;

    s14.addShape(pres.shapes.RECTANGLE, {
      x: fx, y: fy, w: flowW, h: flowH,
      fill: { color: step.color },
    });
    s14.addText(step.label, {
      x: fx, y: fy, w: flowW / 2, h: flowH,
      fontSize: 8, color: C.white, fontFace: "Calibri",
      align: "center", valign: "middle", bold: true, margin: 0,
    });
    s14.addText(step.desc, {
      x: fx + flowW / 2, y: fy, w: flowW / 2, h: flowH,
      fontSize: 7, color: C.white, fontFace: "Calibri",
      align: "center", valign: "middle", margin: 0,
    });

    // Arrow down (within same column)
    if (i < 4 || (i >= 5 && i < 8)) {
      s14.addShape(pres.shapes.RECTANGLE, {
        x: fx + flowW / 2 - 0.01, y: fy + flowH, w: 0.02, h: flowGap + 0.05,
        fill: { color: C.borderLt },
      });
    }
  });

  // Horizontal connector between columns
  s14.addShape(pres.shapes.RECTANGLE, {
    x: flowX1 + 2.2, y: 1.15 + 4 * (flowH + flowGap + 0.05) + flowH / 2, w: 5.0 - flowX1 - 2.2, h: 0.02,
    fill: { color: C.borderLt },
  });

  // Right panel: details
  addCard(s14, 7.3, 1.1, 2.3, 4.0);
  s14.addShape(pres.shapes.RECTANGLE, {
    x: 7.3, y: 1.1, w: 2.3, h: 0.06,
    fill: { color: C.rxGreen },
  });
  s14.addText("关键技术点", {
    x: 7.5, y: 1.2, w: 1.9, h: 0.3,
    fontSize: 11, color: C.rxGreenLt, fontFace: "Calibri", bold: true, margin: 0,
  });
  s14.addText([
    { text: "• FFT转换", options: { bold: true, color: C.white, breakLine: true, fontSize: 8 } },
    { text: "时域→频域", options: { color: C.text, breakLine: true, fontSize: 8 } },
    { text: "• ZF均衡", options: { bold: true, color: C.white, breakLine: true, fontSize: 8 } },
    { text: "压缩信道影响", options: { color: C.text, breakLine: true, fontSize: 8 } },
    { text: "• 硬判决", options: { bold: true, color: C.white, breakLine: true, fontSize: 8 } },
    { text: "最近星座点判决", options: { color: C.text, breakLine: true, fontSize: 8 } },
    { text: "• 反置换", options: { bold: true, color: C.white, breakLine: true, fontSize: 8 } },
    { text: "恢复交织前顺序", options: { color: C.text, breakLine: true, fontSize: 8 } },
    { text: "• 维特比译码", options: { bold: true, color: C.white, breakLine: true, fontSize: 8 } },
    { text: "最大似然序列估计", options: { color: C.text, breakLine: true, fontSize: 8 } },
    { text: "• CRC校验", options: { bold: true, color: C.white, breakLine: true, fontSize: 8 } },
    { text: "帧错误检测", options: { color: C.text, breakLine: true, fontSize: 8 } },
    { text: "• BER统计", options: { bold: true, color: C.white, fontSize: 8 } },
    { text: "总性能指标", options: { color: C.text, fontSize: 8 } },
  ], {
    x: 7.5, y: 1.55, w: 1.9, h: 3.4,
    fontFace: "Calibri", margin: 0,
  });

  addBackButton(s14);
  addSlideNumber(s14, 14);

  // ============================================================
  // SLIDE 15: Summary & TODO
  // ============================================================
  let s15 = pres.addSlide();
  s15.background = { color: C.bg };
  addTopBar(s15, "当前进度与待完成工作", "Current Progress & TODO");

  // Completed items
  addCard(s15, 0.4, 1.1, 4.6, 4.0);
  s15.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 1.1, w: 4.6, h: 0.06,
    fill: { color: C.success },
  });
  s15.addText("✓ 已完成 (Completed)", {
    x: 0.7, y: 1.2, w: 4.0, h: 0.4,
    fontSize: 15, color: C.success, fontFace: "Calibri", bold: true, margin: 0,
  });

  const completed = [
    "信源生成（均匀随机比特流）",
    "CRC-16编码（0x1021）",
    "卷积码编码（K=7, R=1/2）",
    "随机交织（rng(42)）",
    "符号调制（QPSK/16QAM/64QAM）",
    "OFDM调制（IFFT + CP）",
    "VHF车载移动信道模型（5-path Rayleigh）",
  ];

  completed.forEach((item, i) => {
    s15.addShape(pres.shapes.RECTANGLE, {
      x: 0.7, y: 1.75 + i * 0.42, w: 0.25, h: 0.25,
      fill: { color: C.success },
    });
    s15.addText("✓", {
      x: 0.7, y: 1.75 + i * 0.42, w: 0.25, h: 0.25,
      fontSize: 11, color: C.white, fontFace: "Calibri",
      align: "center", valign: "middle", margin: 0,
    });
    s15.addText(item, {
      x: 1.05, y: 1.75 + i * 0.42, w: 3.7, h: 0.25,
      fontSize: 10, color: C.text, fontFace: "Calibri", valign: "middle", margin: 0,
    });
  });

  // TODO items
  addCard(s15, 5.3, 1.1, 4.3, 4.0);
  s15.addShape(pres.shapes.RECTANGLE, {
    x: 5.3, y: 1.1, w: 4.3, h: 0.06,
    fill: { color: C.warning },
  });
  s15.addText("○ 待完成 (TODO)", {
    x: 5.6, y: 1.2, w: 3.7, h: 0.4,
    fontSize: 15, color: C.warning, fontFace: "Calibri", bold: true, margin: 0,
  });

  const todos = [
    "接收端时间同步（互相关）",
    "接收端频率同步（CP相关）",
    "信道估计与频域均衡（ZF）",
    "解调 + 反置换 + 维特比译码",
    "CRC校验与BER统计",
    "SNR-BER性能曲线绘制",
    "用户界面 GUI",
  ];

  todos.forEach((item, i) => {
    s15.addShape(pres.shapes.RECTANGLE, {
      x: 5.6, y: 1.75 + i * 0.42, w: 0.25, h: 0.25,
      fill: { color: C.border },
      line: { color: C.warning, width: 0.5 },
    });
    s15.addText("○", {
      x: 5.6, y: 1.75 + i * 0.42, w: 0.25, h: 0.25,
      fontSize: 11, color: C.warning, fontFace: "Calibri",
      align: "center", valign: "middle", margin: 0,
    });
    s15.addText(item, {
      x: 5.95, y: 1.75 + i * 0.42, w: 3.4, h: 0.25,
      fontSize: 10, color: C.text, fontFace: "Calibri", valign: "middle", margin: 0,
    });
  });

  addBackButton(s15);
  addSlideNumber(s15, 15);

  // ============================================================
  // Write output
  // ============================================================
  const outPath = "C:\\Users\\Qianjunyang\\Desktop\\vhf_ofdm\\汇报_VHF_OFDM_系统设计.pptx";
  await pres.writeFile({ fileName: outPath });
  console.log("Presentation saved to: " + outPath);
  console.log("Total slides: 15");
}

main().catch(err => {
  console.error("Error:", err);
  process.exit(1);
});
