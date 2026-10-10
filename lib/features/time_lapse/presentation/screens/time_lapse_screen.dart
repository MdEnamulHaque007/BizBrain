import 'dart:math';

import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:bizbrain/features/time_lapse/application/playback_controller.dart';
import 'package:bizbrain/features/time_lapse/domain/tl_frame.dart';
import 'package:bizbrain/features/time_lapse/domain/tl_frame_factory.dart';
import 'package:bizbrain/features/time_lapse/presentation/widgets/animated_kpi_card.dart';
import 'package:bizbrain/features/time_lapse/presentation/widgets/multi_stage_line_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TimeLapseScreen extends ConsumerStatefulWidget {
  const TimeLapseScreen({super.key});
  @override
  ConsumerState<TimeLapseScreen> createState() => _TimeLapseScreenState();
}

class _TimeLapseScreenState extends ConsumerState<TimeLapseScreen> {
  final Set<String> _selectedLabels = <String>{};
  String _dateField = 'Auto detect';
  String _qtyField = 'Auto detect';
  String _range = '30 days';
  String _group = 'Day';
  bool _showMovingAverage = false;
  late final PlaybackController _playback;
  String _lastFrameKey = '';

  static const _dateAliases = ['date','timestamp','createdat','updatedat','cuttingdate','sewingdate','lastingdate','productiondate','issuedate','shipmentdate','exportdate','entrydate','entered date','entry date','created date','order date','delivery date','expected date','ship date','completion date'];
  static const _qtyAliases = ['quantity','qty','cuttingquantity','sewingquantity','lastingquantity','productionquantity','issuequantity','shipmentquantity','exportquantity','fgquantity','poquantity','totalquantity','v.no','vno','v no','types','nos','no','number','count','total','pcs','pieces','units','produced','output','balance','stock','inventory','available'];

  @override
  void initState() {
    super.initState();
    _playback = PlaybackController();
  }

  @override
  void dispose() {
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Lapse'),
        leading: Container(margin: const EdgeInsets.all(9),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary,c.tertiary]), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.timelapse_rounded,color:c.onPrimary)),
        actions: [IconButton(tooltip:'Reload sources',onPressed:((){final orgId=ref.read(effectiveOrganizationProvider)?.id??'';ref.invalidate(sourcesListProvider(orgId));}),icon:const Icon(Icons.refresh_rounded))],
      ),
      body: ref.watch(sourcesListProvider(ref.watch(effectiveOrganizationProvider)?.id ?? '')).when(
        loading:()=>const _SkeletonLoader(),
        error:(e,_)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Text('Could not load Google Sheets cache: $e'))),
        data:(all)=>_report(context,all),
      ),
    );
  }

  Widget _report(BuildContext context,List<SheetCacheModel> all) {
    final theme=Theme.of(context); final c=theme.colorScheme;
    final sources=all.where(_isProduction).toList();
    final labels=sources.map(_label).toSet().toList()..sort();
    _selectedLabels.removeWhere((label) => !labels.contains(label));
    final selected = _selectedLabels.isEmpty
        ? sources
        : sources.where((s) => _selectedLabels.contains(_label(s))).toList();
    final dates=selected.expand((s)=>s.columns).where(_isDateField).toSet().toList()..sort();
    final quantities=selected.expand((s)=>s.columns).where(_isQtyField).toSet().toList()..sort();
    if(!dates.contains(_dateField)) _dateField='Auto detect';
    if(!quantities.contains(_qtyField)) _qtyField='Auto detect';
    final raw=<_Point>[];
    for(final s in selected) {
      final df=_dateField!='Auto detect'&&s.columns.contains(_dateField)?_dateField:_best(s.columns,_dateAliases);
      final qf=_qtyField!='Auto detect'&&s.columns.contains(_qtyField)?_qtyField:_best(s.columns,_qtyAliases,rows:s.rows);
      if(df==null||qf==null) continue;
      for(final row in s.rows) {
        final date=_parseDate(row[df]); final qty=_parseQty(row[qf]);
        if(date!=null&&qty!=null) raw.add(_Point(date,qty,_label(s),df,qf));
      }
    }
    raw.sort((a,b)=>a.date.compareTo(b.date));
    final filtered=_filter(raw);
    final grouped=<DateTime,double>{};
    for(final p in filtered) {
      final d=_bucket(p.date);
      grouped[d]=(grouped[d]??0)+p.qty;
    }
    final graph=grouped.entries.toList()..sort((a,b)=>a.key.compareTo(b.key));
    debugPrint('[TimeLapse] Date field: $_dateField');
    debugPrint('[TimeLapse] Qty field: $_qtyField');
    debugPrint('[TimeLapse] Raw points: ${raw.length}');
    debugPrint('[TimeLapse] Filtered: ${filtered.length}');
    debugPrint('[TimeLapse] Grouped: ${graph.length}');
    final frameKey = graph.map((e) => '${e.key}:${e.value}').join('|');
    if (frameKey != _lastFrameKey) {
      _lastFrameKey = frameKey;
      _playback.load(const TLFrameFactory().build(graph, cumulative: true));
    }
    final trendValues = graph.map((e) => e.value).toList();
    final trendMean = trendValues.isEmpty ? 0.0 : trendValues.reduce((a, b) => a + b) / trendValues.length;
    final variance = trendValues.isEmpty ? 0.0 : trendValues.map((v) => pow(v - trendMean, 2).toDouble()).reduce((a, b) => a + b) / trendValues.length;
    final anomalyThreshold = sqrt(variance) * 2;
    final anomalies = graph.where((e) => anomalyThreshold > 0 && (e.value - trendMean).abs() > anomalyThreshold).toList();
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Time Lapse'),
          leading: Container(margin: const EdgeInsets.all(9),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary,c.tertiary]), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.timelapse_rounded,color:c.onPrimary)),
          actions: [
            IconButton(tooltip:'Reload sources',onPressed:((){final orgId=ref.read(effectiveOrganizationProvider)?.id??'';ref.invalidate(sourcesListProvider(orgId));}),icon:const Icon(Icons.refresh_rounded)),
            IconButton(tooltip:'Chart options',onPressed:_openChartOptions,icon:const Icon(Icons.tune_rounded)),
            IconButton(tooltip:'Export CSV',onPressed:()=>_openExport(filtered),icon:const Icon(Icons.download_rounded)),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(icon: Icon(Icons.insert_chart_outlined_rounded), text: 'Trend'),
              Tab(icon: Icon(Icons.compare_arrows_rounded), text: 'Compare'),
              Tab(icon: Icon(Icons.view_timeline_rounded), text: 'Timeline'),
              Tab(icon: Icon(Icons.warning_amber_rounded), text: 'Anomaly'),
            ],
          ),
        ),
        body: Container(
          decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[c.primary.withValues(alpha:.035),c.surface])),
          child: TabBarView(children: [
            _trendTab(context, all, labels, selected, filtered, dates, quantities, graph, sources),
            _compareTab(context, filtered),
            _timelineTab(context, filtered),
            _anomalyTab(context, anomalies, trendMean),
          ]),
        ),
      ),
    );
  }

  // ── Tabs ────────────────────────────────────────────────────────────────

  Widget _trendTab(BuildContext context, List<SheetCacheModel> all, List<String> labels,
      List<SheetCacheModel> selected, List<_Point> filtered, List<String> dates,
      List<String> quantities, List<MapEntry<DateTime, double>> graph, List<SheetCacheModel> sources) {
    final theme=Theme.of(context); final c=theme.colorScheme;
    final total=filtered.fold<double>(0,(sum,p)=>sum+p.qty);
    final average = filtered.isEmpty ? 0.0 : total / filtered.length;
    final peak = filtered.isEmpty ? 0.0 : filtered.map((p) => p.qty).reduce((a, b) => a > b ? a : b);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hero(context),
        const SizedBox(height:14),
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth >= 840 ? 4 : 2;
          final w = (box.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(spacing:10,runSpacing:10,children:[
            SizedBox(width:w,child:_frameKpi(context,'Total',_kpiTotal(total,_playback.current),Icons.inventory_2_outlined,c.primary,_growthTrend(_frameGrowth(_playback.current)))),
            SizedBox(width:w,child:_frameKpi(context,'Average',_kpiAvg(average,_playback.current),Icons.functions_rounded,c.tertiary,0)),
            SizedBox(width:w,child:_frameKpi(context,'Peak',_kpiPeak(peak,_playback.current),Icons.trending_up_rounded,c.secondary,1)),
            SizedBox(width:w,child:_frameKpi(context,'Growth',_frameGrowth(_playback.current),Icons.insights_rounded,_frameGrowth(_playback.current)>=0?Colors.green.shade700:Colors.red.shade600,_growthTrend(_frameGrowth(_playback.current)),isPercent:true)),
          ]);
        }),
        const SizedBox(height:14),
        _compactFilters(context, dates, quantities),
        if (labels.isNotEmpty) ...[
          const SizedBox(height:12),
          _stageChips(context, labels),
        ],
        const SizedBox(height:14),
        if(sources.isEmpty)_empty(context,'No production sheets found','Open Data Sources and load the Cutting and Sewing Google Sheets first.',
          onAction:(){})
        else AnimatedBuilder(
          animation: _playback,
          builder: (context, _) => Card(
            elevation:0,
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20),side:BorderSide(color:c.outlineVariant)),
            child:graph.isEmpty
              ?_empty(context,'No matching date and quantity rows','Check the selected headers or choose All dates. Only real numeric quantities with readable dates are plotted.',
                  onAction:(){})
              :LayoutBuilder(builder:(context,box){
                final height = min(500.0, max(400.0, box.maxWidth*0.45));
                final current = _playback.current;
                final activeFiltered = current == null
                    ? filtered
                    : filtered
                          .where((p) => !p.date.isAfter(current.date))
                          .toList();
                return Stack(children:[
                  Padding(padding:const EdgeInsets.fromLTRB(16,40,16,8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    _playbackBar(context),
                    const SizedBox(height:8),
                    MultiStageLineChart(
                      series: _buildStageSeries(activeFiltered),
                      showMovingAverage: _showMovingAverage,
                      movingAverageSeries: _showMovingAverage
                          ? _computeMovingAverage(activeFiltered, 7)
                          : null,
                      height: height,
                    ),
                    const SizedBox(height:8),Text('X-axis: $_group · Y-axis: summed quantity · Pinch to zoom',style:theme.textTheme.bodySmall?.copyWith(color:c.onSurfaceVariant)),
                    const SizedBox(height:4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Show 7-day moving average'),
                      value: _showMovingAverage,
                      onChanged: (v) => setState(() => _showMovingAverage = v),
                    ),
                  ])),
                  Positioned(top:4,right:4,child:IconButton(
                    tooltip:'Fullscreen',
                    onPressed:()=>_openFullscreen(activeFiltered),
                    icon:const Icon(Icons.fullscreen_rounded),
                  )),
                ]);
              }),
          ),
        ),
      ],
    );
  }

  Widget _compareTab(BuildContext context, List<_Point> filtered) {
    final theme=Theme.of(context); final c=theme.colorScheme;
    final byStage=<String,List<double>>{};
    for (final p in filtered) {
      byStage.putIfAbsent(p.source,()=>[]).add(p.qty);
    }
    if(byStage.isEmpty) return Center(child:_empty(context,'No data to compare','Feed rows into the Time Lapse report first.',onAction:(){}));
    final rows=byStage.entries.toList()..sort((a,b){final x=_sum(b.value);return x.compareTo(_sum(a.value));});
    final maxRows = rows.map((e)=>e.value.length).fold<int>(0,(a,b)=>a>b?a:b);
    return ListView(padding:const EdgeInsets.all(16),children:[
      Card(elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20),side:BorderSide(color:c.outlineVariant)),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
        headingRowColor:WidgetStatePropertyAll(c.primaryContainer.withValues(alpha:.7)),
        columns:const [DataColumn(label:Text('Stage / Sheet')),DataColumn(label:Text('Rows'),numeric:true),DataColumn(label:Text('Total'),numeric:true),DataColumn(label:Text('Average'),numeric:true),DataColumn(label:Text('Peak'),numeric:true),DataColumn(label:Text('Variance'),numeric:true)],
        rows:rows.map((e)=>DataRow(cells:[
          DataCell(Text(e.key)),
          DataCell(Text('${e.value.length}')),
          DataCell(Text(_fmt(_sum(e.value)))),
          DataCell(Text(_fmt(_sum(e.value)/max(1,e.value.length)))),
          DataCell(Text(_fmt(e.value.reduce(max)))),
          DataCell(Text(_fmt(_variance(e.value)))),
        ])).toList(),
      ))),
      const SizedBox(height:10),
      Row(children:[Icon(Icons.info_outline,size:16,color:c.onSurfaceVariant),const SizedBox(width:6),Text('Compared by summed quantity across $maxRows buckets.',style:theme.textTheme.bodySmall?.copyWith(color:c.onSurfaceVariant))]),
    ]);
  }

  Widget _timelineTab(BuildContext context, List<_Point> filtered) {
    final theme=Theme.of(context); final c=theme.colorScheme;
    return ListView(padding:const EdgeInsets.all(16),children:[
      if(filtered.isEmpty)_empty(context,'No timeline records','Feed rows into the Time Lapse report first.',onAction:(){})
      else ...[
        Card(elevation:0,clipBehavior:Clip.antiAlias,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),side:BorderSide(color:c.outlineVariant)),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
          headingRowColor:WidgetStatePropertyAll(c.primaryContainer.withValues(alpha:.7)),
          columns:const [DataColumn(label:Text('Date')),DataColumn(label:Text('Stage / Sheet')),DataColumn(label:Text('Quantity'),numeric:true),DataColumn(label:Text('Date field')),DataColumn(label:Text('Quantity field'))],
          rows:filtered.reversed.take(100).map((p)=>DataRow(cells:[DataCell(Text(_date(p.date))),DataCell(Text(p.source)),DataCell(Text(_fmt(p.qty))),DataCell(Text(p.dateField)),DataCell(Text(p.qtyField))])).toList(),
        ))),
        if(filtered.length>100)Padding(padding:const EdgeInsets.all(8),child:Text('Showing latest 100 of ${filtered.length} rows.',style:theme.textTheme.bodySmall)),
      ],
    ]);
  }

  Widget _anomalyTab(BuildContext context, List<MapEntry<DateTime,double>> anomalies, double trendMean) {
    final theme=Theme.of(context); final c=theme.colorScheme;
    return ListView(padding:const EdgeInsets.all(16),children:[
      Card(
        elevation:0,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20),side:BorderSide(color:c.outlineVariant)),
        child:Padding(
          padding:const EdgeInsets.all(16),
          child:anomalies.isEmpty
            ?_empty(context,'No clear anomalies detected','Trend points are checked against the mean using a 2-standard-deviation threshold.',onAction:(){})
            :Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('${anomalies.length} unusual trend point(s) detected',style:theme.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)),
              const SizedBox(height:8),
              ...anomalies.map((point)=>ListTile(
                dense:true,
                leading:Icon(Icons.warning_amber_rounded,color:c.error),
                title:Text(_date(point.key)),
                subtitle:Text('Average: ${_fmt(trendMean)} · Difference: ${_fmt(point.value-trendMean)}'),
                trailing:Text(_fmt(point.value),style:theme.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)),
              )),
            ]),
        ),
      ),
    ]);
  }

  // ── Building blocks ─────────────────────────────────────────────────────

  Widget _playbackBar(BuildContext context) {
    final theme = Theme.of(context);
    final current = _playback.current;
    return AnimatedBuilder(
      animation: _playback,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: .35,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: _playback.isPlaying ? 'Pause' : 'Play',
                onPressed: _playback.isEnabled
                    ? () => setState(() => _playback.toggle())
                    : null,
                icon: Icon(
                  _playback.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          current == null
                              ? 'No timeline'
                              : _date(current.date),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _playback.length < 2
                              ? '·'
                              : '${_playback.index + 1}/${_playback.length}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _playback.progress,
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Restart',
                onPressed: _playback.isEnabled
                    ? () => setState(() => _playback.restart())
                    : null,
                icon: const Icon(Icons.replay_rounded),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _hero(BuildContext context) {
    final theme=Theme.of(context); final c=theme.colorScheme;
    return Container(
      padding:const EdgeInsets.all(20),
      decoration:BoxDecoration(gradient:LinearGradient(colors:[c.primary,c.tertiary],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(24)),
      child:Row(children:[
        Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.15),borderRadius:BorderRadius.circular(16)),child:Icon(Icons.timeline_rounded,size:28,color:c.onPrimary)),
        const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Production Time Lapse',style:theme.textTheme.headlineSmall?.copyWith(color:c.onPrimary,fontWeight:FontWeight.w800)),
          const SizedBox(height:4),Text('Explore quantity trends from cached Google Sheets.',style:theme.textTheme.bodyMedium?.copyWith(color:c.onPrimary.withValues(alpha:.9)))
        ])),
      ]),
    );
  }

  Widget _compactFilters(BuildContext context, List<String> dates, List<String> quantities) {
    final c=Theme.of(context).colorScheme;
    return Card(
      elevation:0,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),side:BorderSide(color:c.outlineVariant)),
      child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),child:LayoutBuilder(builder:(context,box){
        final wide=box.maxWidth>=980;
        final filters=[
          _drop(context,'Date field',_dateField,['Auto detect',...dates],Icons.event_rounded,(v)=>setState(()=>_dateField=v)),
          _drop(context,'Qty field',_qtyField,['Auto detect',...quantities],Icons.numbers_rounded,(v)=>setState(()=>_qtyField=v)),
          _drop(context,'Date range',_range,const ['7 days','30 days','90 days','All dates'],Icons.date_range_rounded,(v)=>setState(()=>_range=v)),
          _drop(context,'Group by',_group,const ['Day','Week','Month'],Icons.view_agenda_rounded,(v)=>setState(()=>_group=v)),
        ];
        if(wide) return Row(children:[for(final f in filters) Expanded(child:Builder(builder:(context)=>f))]);
        return Wrap(spacing:8,runSpacing:8,children:[
          for(final f in filters) SizedBox(width:(box.maxWidth-40)/2,child:f),
        ]);
      })),
    );
  }

  Widget _stageChips(BuildContext context, List<String> labels) {
    final c=Theme.of(context).colorScheme;
    return SizedBox(
      height:48,
      child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        _chip(
          label:_selectedLabels.isEmpty?'All stages (${labels.length})':'All stages',
          color:c.primary,selected:_selectedLabels.isEmpty,
          onTap:()=>setState(()=>_selectedLabels.clear()),
        ),
        const SizedBox(width:8),
        for(var i=0;i<labels.length;i++)...[ 
          _chip(
            label:labels[i],
            color:MultiStageLineChart.colorFor(i),
            selected:_selectedLabels.contains(labels[i]),
            onTap:()=>setState((){
              if(_selectedLabels.contains(labels[i])){_selectedLabels.remove(labels[i]);}
              else{_selectedLabels.add(labels[i]);}
            }),
          ),
          const SizedBox(width:8),
        ],
      ])),
    );
  }

  Widget _chip({required String label,required Color color,required bool selected,required VoidCallback onTap}) {
    final c=Theme.of(context).colorScheme;
    return FilterChip(
      selected:selected,
      avatar:selected?null:Container(width:10,height:10,decoration:BoxDecoration(color:color,shape:BoxShape.circle)),
      showCheckmark:true,
      label:Text(label),
      selectedColor:color.withValues(alpha:.18),
      checkmarkColor:color,
      side:BorderSide(color:selected?color:c.outlineVariant),
      onSelected:(_)=>onTap(),
      backgroundColor:c.surfaceContainerHighest.withValues(alpha:.3),
    );
  }

  void _openChartOptions() {
    showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setDialogState)=>AlertDialog(
      title:const Text('Chart options'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        SwitchListTile(
          contentPadding:EdgeInsets.zero,
          title:const Text('Show 7-day moving average'),
          value:_showMovingAverage,
          onChanged:(v){setState(()=>_showMovingAverage=v);setDialogState((){});},
        ),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Done'))],
    )));
  }

  void _openFullscreen(List<_Point> filtered) {
    showDialog<void>(context:context,builder:(dialogContext)=>Dialog.fullscreen(
      backgroundColor:Color.alphaBlend(Colors.black.withValues(alpha:.86),Theme.of(context).colorScheme.surface),
      child:Stack(children:[
        Padding(padding:const EdgeInsets.all(24),child:Center(child:MultiStageLineChart(
          series:_buildStageSeries(filtered),
          showMovingAverage:_showMovingAverage,
          movingAverageSeries:_showMovingAverage?_computeMovingAverage(filtered,7):null,
          height:MediaQuery.of(dialogContext).size.height*0.7,
        ))),
        Positioned(top:8,right:8,child:IconButton(onPressed:()=>Navigator.pop(dialogContext),icon:const Icon(Icons.close_rounded,color:Colors.white))),
      ]),
    ));
  }

  void _openExport(List<_Point> filtered) {
    final csv=StringBuffer()..writeln('date,source,quantity,dateField,quantityField');
    for(final p in filtered){csv.writeln('${_date(p.date)},${p.source},${_fmt(p.qty)},${p.dateField},${p.qtyField}');}
    showModalBottomSheet<void>(context:context,builder:(sheetContext)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const SizedBox(height:12),
      ListTile(leading:const Icon(Icons.description_rounded),title:const Text('Export report'),subtitle:Text('${filtered.length} rows · CSV')),
      const ListTile(
        leading:Icon(Icons.table_chart_rounded),
        title:Text('Copy CSV to clipboard'),
        trailing:Icon(Icons.chevron_right_rounded),
      ),
      Padding(padding:const EdgeInsets.all(16),child:SizedBox(width:double.infinity,child:FilledButton.icon(
        onPressed:(){
          Clipboard.setData(ClipboardData(text:csv.toString()));
          Navigator.pop(sheetContext);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('CSV copied to clipboard')));
        },
        icon:const Icon(Icons.copy_rounded),label:const Text('Copy CSV'),
      ))),
    ])));
  }

  Widget _frameKpi(BuildContext context, String label, double value, IconData icon,
      Color color, int trend, {bool isPercent = false}) {
    return AnimatedKpiCard(
      label: label,
      value: value,
      icon: icon,
      color: color,
      trend: trend,
      prefix: isPercent && value > 0 ? '+' : '',
      suffix: isPercent ? '%' : '',
      formatter: _fmt,
    );
  }

  /// Per-frame total; falls back to the full-range total when idle.
  double _kpiTotal(double full, TLFrame? current) =>
      current?.total ?? full;

  /// Per-frame average = cumulative total over elapsed bucket count.
  double _kpiAvg(double full, TLFrame? current) =>
      current == null ? full : current.total / (current.index + 1);

  /// Per-frame peak = largest cumulative value seen so far.
  double _kpiPeak(double full, TLFrame? current) {
    if (current == null) return full;
    var runningPeak = double.negativeInfinity;
    for (final frame in _playback.frames) {
      if (frame.index > current.index) break;
      if (frame.total > runningPeak) runningPeak = frame.total;
    }
    return runningPeak == double.negativeInfinity ? 0 : runningPeak;
  }

  /// Growth % relative to the first bucket; 0 when idle or no baseline.
  double _frameGrowth(TLFrame? current) {
    if (current == null || _playback.frames.length < 2) return 0;
    final first = _playback.frames.first.total;
    if (first == 0) return 0;
    return (current.total - first) / first * 100;
  }

  int _growthTrend(double growth) =>
      growth < 0 ? -1 : (growth > 0 ? 1 : 0);

  Widget _empty(BuildContext context,String title,String message,{VoidCallback? onAction}){
    final c=Theme.of(context).colorScheme;
    return Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[
      Icon(Icons.query_stats_rounded,size:56,color:c.tertiary),
      const SizedBox(height:12),
      Text(title,textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)),
      const SizedBox(height:8),
      Text(message,textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodyMedium?.copyWith(color:c.onSurfaceVariant,height:1.4)),
      if(onAction!=null)...[const SizedBox(height:16),OutlinedButton.icon(onPressed:onAction,icon:const Icon(Icons.table_view_rounded),label:const Text('Go to Data Sources'))],
    ]));
  }

  // ── Data logic (unchanged) ──────────────────────────────────────────────

  /// Buckets a date according to the selected grouping (Day / Week / Month).
  DateTime _bucket(DateTime date) => _group=='Month'
      ? DateTime(date.year,date.month)
      : _group=='Week'
      ? _week(date)
      : DateTime(date.year,date.month,date.day);

  /// Splits the filtered points into one summed series per stage / sheet.
  Map<String, List<TrendPoint>> _groupByStage(List<_Point> points) {
    final byStage = <String, Map<DateTime, double>>{};
    for (final p in points) {
      final buckets = byStage.putIfAbsent(p.source, () => <DateTime, double>{});
      final d = _bucket(p.date);
      buckets[d] = (buckets[d] ?? 0) + p.qty;
    }
    return byStage.map((stage, buckets) {
      final entries = buckets.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      return MapEntry(stage, entries.map((e) => TrendPoint(date: e.key, value: e.value)).toList(growable: false));
    });
  }

  /// Chart data as one [StageSeries] per stage, colours from the deterministic
  /// palette ordered by the first appearance of each stage.
  List<StageSeries> _buildStageSeries(List<_Point> filtered) {
    final grouped = _groupByStage(filtered);
    final labels = grouped.keys.toList();
    return [
      for (var i = 0; i < labels.length; i++)
        StageSeries(
          stageName: labels[i],
          color: MultiStageLineChart.colorFor(i),
          points: grouped[labels[i]]!,
        ),
    ];
  }

  /// Single overall 7-day moving average across all selected stages,
  /// aggregated per bucket so the overlay is one dashed line.
  List<TrendPoint> _computeMovingAverage(List<_Point> points, int window) {
    if (points.isEmpty) return const <TrendPoint>[];
    final byDate = <DateTime, double>{};
    for (final p in points) {
      final d = _bucket(p.date);
      byDate[d] = (byDate[d] ?? 0) + p.qty;
    }
    final entries = byDate.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final trend = [
      for (final e in entries) TrendPoint(date: e.key, value: e.value),
    ];
    return _movingAverage(trend, window);
  }

  /// Simple trailing moving average over [window] points.
  List<TrendPoint> _movingAverage(List<TrendPoint> points, int window) {
    if (points.length < window) return [];
    final result = <TrendPoint>[];
    for (int i = window - 1; i < points.length; i++) {
      double sum = 0;
      for (int j = 0; j < window; j++) {
        sum += points[i - j].value;
      }
      result.add(TrendPoint(date: points[i].date, value: sum / window));
    }
    return result;
  }

  List<_Point> _filter(List<_Point> points) {
    if(_range=='All dates'||points.isEmpty)return points;
    final days=_range=='7 days'?7:_range=='90 days'?90:30;
    // Anchor the range to the newest date in the selected sheet data, not today.
    // Production sheets are often historical; anchoring to today made valid old
    // records disappear when users selected 7/30/90 days.
    final newest=points.map((p)=>p.date).reduce((a,b)=>a.isAfter(b)?a:b);
    final end=DateTime(newest.year,newest.month,newest.day,23,59,59);
    final start=DateTime(newest.year,newest.month,newest.day).subtract(Duration(days:days-1));
    return points.where((p)=>!p.date.isBefore(start)&&!p.date.isAfter(end)).toList();
  }
  static bool _isProduction(SheetCacheModel s) {
    final n='${s.sourceLabel??''} ${s.sheetName??''} ${s.sourceInput??''}'.toLowerCase();
    return ['cutting','sewing','lasting','production','process order','purchase order','master lc','issue','shipment','export','finished good','fg'].any(n.contains);
  }
  static String _label(SheetCacheModel s) {
    final a=(s.sourceLabel??'').trim(),b=(s.sheetName??'').trim();
    if(a.isEmpty)return b.isEmpty?'Google Sheet':b;
    if(b.isEmpty||a.toLowerCase()==b.toLowerCase())return a;
    return '$a · $b';
  }
  static bool _isDateField(String s){final n=_norm(s);return n.contains('date')||n.contains('timestamp')||n=='createdat'||n=='updatedat'||n.endsWith('time');}
  static bool _isQtyField(String s){final n=_norm(s);return n=='qty'||n.contains('quantity')||n.endsWith('qty')||n=='units';}
  static String _norm(String s)=>s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'),'');
  static String? _best(List<String> cols,List<String> aliases,{List<Map<String,String>>? rows}){
    for(final a in aliases){for(final c in cols){if(_norm(a)==_norm(c))return c;}}
    for(final c in cols){if(aliases==_dateAliases&&_isDateField(c))return c;if(aliases==_qtyAliases&&_isQtyField(c))return c;}
    // Fallback: for quantity, pick the first column where >50% of values parse as numbers.
    if(aliases==_qtyAliases&&rows!=null&&rows.isNotEmpty){
      for(final c in cols){
        if(rows.isEmpty)return null;
        var numeric=0;
        for(final row in rows){if(_parseQty(row[c])!=null)numeric++;}
        if(numeric*2>rows.length)return c;
      }
    }
    return null;
  }
  static DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final v = value.trim();
    final parsed = DateTime.tryParse(v);
    if (parsed != null) return parsed;
    // Google Sheets serial date: day count from 1899-12-30.
    final serial = double.tryParse(v);
    if (serial != null && serial >= 1 && serial < 100000) {
      return DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
    }
    final parts = v.replaceAll('.', '/').replaceAll('-', '/').split('/');
    if (parts.length != 3) return null;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (a == null || b == null || d == null) return null;
    if (parts[0].length == 4) return _safeDate(a, b, d);
    if (a > 12) return _safeDate(d < 100 ? 2000 + d : d, b, a);
    if (b > 12) return _safeDate(d < 100 ? 2000 + d : d, a, b);
    return _safeDate(d < 100 ? 2000 + d : d, b, a);
  }
  static DateTime? _safeDate(int y,int m,int d){if(y<1900||m<1||m>12||d<1||d>31)return null;final x=DateTime(y,m,d);return x.year==y&&x.month==m&&x.day==d?x:null;}
  static double? _parseQty(String? v){if(v==null||v.trim().isEmpty)return null;final n=v.replaceAll(',','').replaceAll(RegExp(r'[^0-9.\-]'),'');if(n.isEmpty||n=='-'||n=='.')return null;return double.tryParse(n);}
  static DateTime _week(DateTime d){final x=DateTime(d.year,d.month,d.day);return x.subtract(Duration(days:x.weekday-1));}
  static String _fmt(double n)=>n==n.roundToDouble()?n.toInt().toString():n.toStringAsFixed(2);
  static String _date(DateTime d)=>'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  static double _sum(List<double> v)=>v.fold<double>(0,(a,b)=>a+b);
  static double _variance(List<double> v){
    if(v.length<2)return 0;final m=_sum(v)/v.length;
    return v.map((x)=>pow(x-m,2).toDouble()).fold<double>(0,(a,b)=>a+b)/v.length;
  }

  Widget _drop(BuildContext context,String label,String value,List<String> options,IconData icon,ValueChanged<String> change){
    final c=Theme.of(context).colorScheme;final unique=options.toSet().toList();final safe=unique.contains(value)?value:unique.first;
    return DropdownButtonFormField<String>(initialValue:safe,isExpanded:true,decoration:InputDecoration(
      labelText:label,prefixIcon:Icon(icon,size:19,color:c.primary),
      filled:true,fillColor:c.surfaceContainerHighest.withValues(alpha:.35),
      contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:12),
      border:OutlineInputBorder(borderRadius:BorderRadius.circular(14)),
      suffixIcon:safe=='Auto detect'||safe=='30 days'||safe=='Day'
        ?null:GestureDetector(onTap:(){change('Auto detect');},child:const Icon(Icons.close_rounded,size:16)),
    ),items:unique.map((s)=>DropdownMenuItem(value:s,child:Text(s,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v){if(v!=null)change(v);});
  }
  }

class _Point {
  const _Point(this.date,this.qty,this.source,this.dateField,this.qtyField);
  final DateTime date;final double qty;final String source,dateField,qtyField;
}

/// Animated shimmer skeleton shown while sources are loading.
class _SkeletonLoader extends StatefulWidget {
  const _SkeletonLoader();
  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _opacity =
      Tween<double>(begin: .35, end: .9).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _opacity,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _box(c, height: 88, radius: 24),
          const SizedBox(height: 16),
          Row(children:[for(var i=0;i<4;i++)...[_box(c,height:120,radius:20,expand:true),if(i<3)const SizedBox(width:8)]]),
          const SizedBox(height: 16),
          _box(c, height: 48, radius: 18),
          const SizedBox(height: 16),
          _box(c, height: 420, radius: 20),
        ],
      ),
    );
  }

  Widget _box(ColorScheme c,{required double height,required double radius,bool expand=false}){
    return Container(
      height:height,
      width:expand?null:double.infinity,
      decoration:BoxDecoration(
        color:c.surfaceContainerHighest.withValues(alpha:.6),
        borderRadius:BorderRadius.circular(radius),
      ),
    );
  }
}