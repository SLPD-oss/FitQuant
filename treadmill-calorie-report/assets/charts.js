// FitQuant 跑步机热量公式研究报告 — 图表数据与渲染
// 所有数值均由 ACSM 步行/跑步公式实时计算（85kg × 30min）
// 步行公式: VO2 = 0.1*S + 1.8*S*G + 3.5；跑步公式: VO2 = 0.2*S + 0.9*S*G + 3.5
// 热量 = VO2 * 85 / 1000 * 30 * 5
(function () {
  var style = getComputedStyle(document.documentElement);
  var accent = style.getPropertyValue('--accent').trim();
  var accent2 = style.getPropertyValue('--accent2').trim();
  var ink = style.getPropertyValue('--ink').trim();
  var muted = style.getPropertyValue('--muted').trim();
  var rule = style.getPropertyValue('--rule').trim();
  var bg2 = style.getPropertyValue('--bg2').trim();

  // 计算工具：步行公式热量（kcal / 30min / 85kg）
  function walkKcal(speedKmh, gradePct) {
    var s = speedKmh * 1000 / 60;          // km/h -> m/min
    var g = gradePct / 100;                // % -> 小数
    var vo2 = 0.1 * s + 1.8 * s * g + 3.5; // 步行公式
    return vo2 * 85 / 1000 * 30 * 5;
  }
  // 跑步公式热量（kcal / 30min / 85kg）
  function runKcal(speedKmh, gradePct) {
    var s = speedKmh * 1000 / 60;
    var g = gradePct / 100;
    var vo2 = 0.2 * s + 0.9 * s * g + 3.5; // 跑步公式
    return vo2 * 85 / 1000 * 30 * 5;
  }

  var baseOpt = {
    animation: false,
    textStyle: { color: ink, fontFamily: '-apple-system, "PingFang SC", sans-serif' },
    tooltip: { appendToBody: true, backgroundColor: bg2, borderColor: rule, textStyle: { color: ink } }
  };

  // ---- 图 1：坡度-速度热量热力图 ----
  var speeds = [3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0];
  var grades = [0, 2, 4, 6, 8, 10, 12, 15];
  var heatData = [];
  grades.forEach(function (g, gi) {
    speeds.forEach(function (sp, si) {
      heatData.push([si, gi, Math.round(walkKcal(sp, g))]);
    });
  });

  var chart1 = echarts.init(document.getElementById('chart-heatmap'), null, { renderer: 'svg' });
  chart1.setOption(Object.assign({}, baseOpt, {
    grid: { top: 30, left: 70, right: 30, bottom: 60 },
    xAxis: {
      type: 'category',
      data: speeds.map(function (s) { return s.toFixed(1) + ' km/h'; }),
      axisLabel: { color: muted },
      axisLine: { lineStyle: { color: rule } },
      name: '速度',
      nameLocation: 'middle',
      nameGap: 38,
      nameTextStyle: { color: muted }
    },
    yAxis: {
      type: 'category',
      data: grades.map(function (g) { return g + '%'; }),
      axisLabel: { color: muted },
      axisLine: { lineStyle: { color: rule } },
      name: '坡度',
      nameTextStyle: { color: muted }
    },
    visualMap: {
      min: 100,
      max: 540,
      calculable: false,
      orient: 'horizontal',
      left: 'center',
      bottom: 0,
      textStyle: { color: muted },
      inRange: { color: [bg2, accent2, accent] },
      outOfRange: { color: 'transparent' }
    },
    series: [{
      type: 'heatmap',
      data: heatData,
      label: { show: true, formatter: function (p) { return p.value[2]; }, color: ink, fontSize: 11 },
      itemStyle: { borderColor: '#0e1526', borderWidth: 2 },
      emphasis: { itemStyle: { borderColor: '#ffffff', borderWidth: 1 } }
    }]
  }));
  window.addEventListener('resize', function () { chart1.resize(); });

  // ---- 图 2：坡度杠杆效应折线图 ----
  var chart2 = echarts.init(document.getElementById('chart-leverage'), null, { renderer: 'svg' });
  chart2.setOption(Object.assign({}, baseOpt, {
    color: [accent, accent2, '#6fd08c'],
    legend: { textStyle: { color: muted }, top: 0 },
    grid: { top: 50, left: 60, right: 30, bottom: 40 },
    xAxis: {
      type: 'category',
      data: grades.map(function (g) { return g + '%'; }),
      axisLabel: { color: muted },
      axisLine: { lineStyle: { color: rule } },
      name: '坡度',
      nameTextStyle: { color: muted }
    },
    yAxis: {
      type: 'value',
      name: 'kcal / 30min',
      axisLabel: { color: muted },
      splitLine: { lineStyle: { color: rule } },
      nameTextStyle: { color: muted }
    },
    series: [
      { name: '4.0 km/h', type: 'line', smooth: true, symbolSize: 7, data: grades.map(function (g) { return Math.round(walkKcal(4.0, g)); }) },
      { name: '5.0 km/h', type: 'line', smooth: true, symbolSize: 7, data: grades.map(function (g) { return Math.round(walkKcal(5.0, g)); }) },
      { name: '6.0 km/h', type: 'line', smooth: true, symbolSize: 7, data: grades.map(function (g) { return Math.round(walkKcal(6.0, g)); }) }
    ]
  }));
  window.addEventListener('resize', function () { chart2.resize(); });

  // ---- 图 3：步行 vs 跑步公式平地对比（柱状图） ----
  var walkSpeeds = [3.0, 4.0, 5.0, 6.0];      // 步行公式适用
  var runSpeeds = [8.0, 9.0, 10.0, 12.0];     // 跑步公式适用
  var cats = [];
  var walkVals = [];
  var runVals = [];
  walkSpeeds.forEach(function (s) {
    cats.push(s.toFixed(1) + ' km/h');
    walkVals.push(Math.round(walkKcal(s, 0)));
    runVals.push(null);
  });
  runSpeeds.forEach(function (s) {
    cats.push(s.toFixed(1) + ' km/h');
    walkVals.push(null);
    runVals.push(Math.round(runKcal(s, 0)));
  });

  var chart3 = echarts.init(document.getElementById('chart-walkrun'), null, { renderer: 'svg' });
  chart3.setOption(Object.assign({}, baseOpt, {
    color: [accent, accent2],
    legend: { textStyle: { color: muted }, top: 0 },
    grid: { top: 50, left: 60, right: 30, bottom: 40 },
    xAxis: {
      type: 'category',
      data: cats,
      axisLabel: { color: muted },
      axisLine: { lineStyle: { color: rule } },
      name: '平地速度（0% 坡度）',
      nameLocation: 'middle',
      nameGap: 34,
      nameTextStyle: { color: muted }
    },
    yAxis: {
      type: 'value',
      name: 'kcal / 30min',
      axisLabel: { color: muted },
      splitLine: { lineStyle: { color: rule } },
      nameTextStyle: { color: muted }
    },
    series: [
      { name: '步行公式', type: 'bar', barMaxWidth: 34, data: walkVals, label: { show: true, position: 'top', color: muted, fontSize: 11 } },
      { name: '跑步公式', type: 'bar', barMaxWidth: 34, data: runVals, label: { show: true, position: 'top', color: muted, fontSize: 11 } }
    ]
  }));
  window.addEventListener('resize', function () { chart3.resize(); });
})();
