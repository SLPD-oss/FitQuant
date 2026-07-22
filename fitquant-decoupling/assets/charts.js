// ── FitQuant Decoupling Charts ──
(function() {
  var style = getComputedStyle(document.documentElement);
  var accent = style.getPropertyValue('--accent').trim();
  var accent2 = style.getPropertyValue('--accent2').trim();
  var ink = style.getPropertyValue('--ink').trim();
  var muted = style.getPropertyValue('--muted').trim();
  var rule = style.getPropertyValue('--rule').trim();
  var bg2 = style.getPropertyValue('--bg2').trim();
  var bg = style.getPropertyValue('--bg').trim();

  // ─── Chart: Effort (hours per step) ───
  var chartEffort = echarts.init(document.getElementById('chart-effort'), null, { renderer: 'svg' });
  chartEffort.setOption({
    animation: false,
    tooltip: { trigger: 'axis', appendToBody: true, axisPointer: { type: 'shadow' } },
    grid: { left: 60, right: 40, top: 20, bottom: 40 },
    xAxis: {
      type: 'category',
      data: ['Step 1\nRepository', 'Step 2\nService', 'Step 3\nManager\n拆分', 'Step 4\n公式\n统一', 'Step 5\nViewModel\n引入', 'Step 6\n代码\n清理'],
      axisLabel: { color: muted, fontSize: 11, lineHeight: 14, interval: 0 },
      axisLine: { lineStyle: { color: rule } },
      axisTick: { show: false }
    },
    yAxis: {
      type: 'value',
      name: '小时',
      nameTextStyle: { color: muted, fontSize: 11 },
      axisLabel: { color: muted, fontSize: 11 },
      splitLine: { lineStyle: { color: rule, type: 'dashed' } },
      axisLine: { show: false },
      axisTick: { show: false }
    },
    series: [{
      type: 'bar',
      data: [2, 4, 1, 1, 12, 0.5],
      itemStyle: {
        borderRadius: [4, 4, 0, 0],
        color: function(params) {
          var colors = [accent, accent2, accent, accent2, '#dc2626', '#059669'];
          return colors[params.dataIndex];
        }
      },
      label: {
        show: true,
        position: 'top',
        color: muted,
        fontSize: 11,
        fontWeight: 600,
        formatter: function(p) { return p.value + 'h'; }
      }
    }]
  });
  window.addEventListener('resize', function() { chartEffort.resize(); });

  // ─── Chart: LOC breakdown (new + modified per step) ───
  var chartLOC = echarts.init(document.getElementById('chart-loc'), null, { renderer: 'svg' });
  chartLOC.setOption({
    animation: false,
    tooltip: { trigger: 'axis', appendToBody: true, axisPointer: { type: 'shadow' } },
    legend: {
      data: ['新增行', '修改行'],
      bottom: 0,
      left: 'center',
      textStyle: { color: muted, fontSize: 12 }
    },
    grid: { left: 60, right: 40, top: 20, bottom: 50 },
    xAxis: {
      type: 'category',
      data: ['Step 1\nRepository', 'Step 2\nService', 'Step 3\nManager', 'Step 4\n公式统一', 'Step 5\nViewModel', 'Step 6\n清理'],
      axisLabel: { color: muted, fontSize: 11, interval: 0 },
      axisLine: { lineStyle: { color: rule } },
      axisTick: { show: false }
    },
    yAxis: {
      type: 'value',
      name: '代码行数',
      nameTextStyle: { color: muted, fontSize: 11 },
      axisLabel: { color: muted, fontSize: 11 },
      splitLine: { lineStyle: { color: rule, type: 'dashed' } },
      axisLine: { show: false },
      axisTick: { show: false }
    },
    series: [
      {
        name: '新增行',
        type: 'bar',
        stack: 'total',
        barWidth: '50%',
        data: [150, 300, 0, 0, 400, 0],
        itemStyle: { color: accent, borderRadius: [0, 0, 0, 0] },
        label: {
          show: true,
          position: 'inside',
          color: '#fff',
          fontSize: 10,
          fontWeight: 600,
          formatter: function(p) { return p.value > 0 ? p.value : ''; }
        }
      },
      {
        name: '修改行',
        type: 'bar',
        stack: 'total',
        barWidth: '50%',
        data: [20, 40, 50, 40, 200, 10],
        itemStyle: { color: accent2, borderRadius: [4, 4, 0, 0] },
        label: {
          show: true,
          position: 'inside',
          color: '#fff',
          fontSize: 10,
          fontWeight: 600,
          formatter: function(p) { return p.value > 0 ? p.value : ''; }
        }
      }
    ]
  });
  window.addEventListener('resize', function() { chartLOC.resize(); });
})();
