// FitQuant Network API Plan Charts
(function() {
  var style = getComputedStyle(document.documentElement);
  var accent = style.getPropertyValue('--accent').trim();
  var accent2 = style.getPropertyValue('--accent2').trim();
  var ink = style.getPropertyValue('--ink').trim();
  var muted = style.getPropertyValue('--muted').trim();
  var rule = style.getPropertyValue('--rule').trim();

  var chartEffort = echarts.init(document.getElementById('chart-effort'), null, { renderer: 'svg' });
  chartEffort.setOption({
    animation: false,
    tooltip: { trigger: 'axis', appendToBody: true, axisPointer: { type: 'shadow' } },
    grid: { left: 60, right: 40, top: 20, bottom: 60 },
    xAxis: {
      type: 'category',
      data: ['认证\n登录', '身体\n数据', '补剂\n方案', '食物\n识别', '药品\n分类', '动作\n分类', '风险\n校验', '数据\n同步'],
      axisLabel: { color: muted, fontSize: 11, lineHeight: 14, interval: 0 },
      axisLine: { lineStyle: { color: rule } },
      axisTick: { show: false }
    },
    yAxis: {
      type: 'value',
      name: '人天',
      nameTextStyle: { color: muted, fontSize: 11 },
      axisLabel: { color: muted, fontSize: 11 },
      splitLine: { lineStyle: { color: rule, type: 'dashed' } },
      axisLine: { show: false },
      axisTick: { show: false }
    },
    series: [{
      type: 'bar',
      data: [3, 3, 4, 7, 3, 4, 2, 4],
      itemStyle: {
        borderRadius: [4, 4, 0, 0],
        color: function(params) {
          var colors = ['#dc2626', '#dc2626', '#dc2626', '#059669', '#d97706', '#d97706', '#d97706', '#059669'];
          return colors[params.dataIndex];
        }
      },
      label: {
        show: true,
        position: 'top',
        color: muted,
        fontSize: 11,
        fontWeight: 600,
        formatter: function(p) { return p.value + 'd'; }
      },
      markLine: {
        silent: true,
        lineStyle: { color: '#dc2626', type: 'dashed', width: 1.5 },
        label: { show: true, formatter: 'P0 小计 10d', color: '#dc2626', fontSize: 10, position: 'end' },
        data: [{ xAxis: 3 }]
      }
    }]
  });
  window.addEventListener('resize', function() { chartEffort.resize(); });
})();
