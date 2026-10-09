import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
import 'dart:math' as math;\nimport 'package:flutter/material.dart';
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

  static const _dateAliases = ['date','timestamp','createdat','updatedat','cuttingdate','sewingdate','lastingdate','productiondate','issuedate','shipmentdate','exportdate','entrydate'];
  static const _qtyAliases = ['quantity','qty','cuttingquantity','sewingquantity','lastingquantity','productionquantity','issuequantity','shipmentquantity','exportquantity','fgquantity','poquantity','totalquantity'];

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Lapse'),
        leading: Container(margin: const EdgeInsets.all(9),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary,c.tertiary]), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.timelapse_rounded,color:c.onPrimary)),
        actions: [IconButton(tooltip:'Reload sources',onPressed:()=>ref.invalidate(sourcesListProvider),icon:const Icon(Icons.refresh_rounded))],
      ),
      body: ref.watch(sourcesListProvider).when(
        loading:()=>const Center(child:CircularProgressIndicator()),
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
      final qf=_qtyField!='Auto detect'&&s.columns.contains(_qtyField)?_qtyField:_best(s.columns,_qtyAliases);
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
      final d=_group=='Month'?DateTime(p.date.year,p.date.month):_group=='Week'?_week(p.date):DateTime(p.date.year,p.date.month,p.date.day);
      grouped[d]=(grouped[d]??0)+p.qty;
    }
    final graph=grouped.entries.toList()..sort((a,b)=>a.key.compareTo(b.key));
    final graphAverage=graph.isEmpty?0.0:graph.map((p)=>p.value).reduce((a,b)=>a+b)/graph.length;
    final total=filtered.fold<double>(0,(sum,p)=>sum+p.qty);
    final average=filtered.isEmpty?0.0:total/filtered.length;
    final peak=filtered.isEmpty?0.0:filtered.map((p)=>p.qty).reduce((a,b)=>a>b?a:b);
    final lowest=filtered.isEmpty?0.0:filtered.map((p)=>p.qty).reduce((a,b)=>a<b?a:b);
    final anomalies=_detectAnomalies(graph);
    final bottlenecks=_stageTotals(filtered);
    return Container(
      decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[c.primary.withValues(alpha:.035),c.surface])),
      child:ListView(padding:const EdgeInsets.all(20),children:[
        Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(gradient:LinearGradient(colors:[c.primary,c.tertiary],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(24)),
          child:Row(children:[Icon(Icons.timeline_rounded,size:38,color:c.onPrimary),const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Production Time Lapse',style:theme.textTheme.headlineSmall?.copyWith(color:c.onPrimary,fontWeight:FontWeight.w800)),
            const SizedBox(height:6),Text('Explore quantity trends from cached Google Sheets.',style:theme.textTheme.bodyMedium?.copyWith(color:c.onPrimary.withValues(alpha:.9)))
          ]))])),
        const SizedBox(height:18),_title(context,'Customize report',Icons.tune_rounded),const SizedBox(height:12),
        Card(elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20),side:BorderSide(color:c.outlineVariant)),child:Padding(padding:const EdgeInsets.all(16),child:LayoutBuilder(builder:(context,box){
          final w=box.maxWidth>=760?(box.maxWidth-24)/3:box.maxWidth>=480?(box.maxWidth-12)/2:box.maxWidth;
          return Wrap(spacing:12,runSpacing:12,children:[
            SizedBox(width:w,child:_drop(context,'Date field',_dateField,['Auto detect',...dates],(v)=>setState(()=>_dateField=v))),
            SizedBox(width:w,child:_drop(context,'Quantity field',_qtyField,['Auto detect',...quantities],(v)=>setState(()=>_qtyField=v))),
            SizedBox(width:w,child:_drop(context,'Date range',_range,const ['7 days','30 days','90 days','All dates'],(v)=>setState(()=>_range=v))),
            SizedBox(width:w,child:_drop(context,'Group trend by',_group,const ['Day','Week','Month'],(v)=>setState(()=>_group=v))),
          ]);
        }))),
        if (labels.isNotEmpty) ...[
          const SizedBox(height:12),
          _title(context, 'Compare stages / sheets', Icons.compare_arrows_rounded),
          const SizedBox(height:8),
          Wrap(spacing:8, runSpacing:8, children: [
            FilterChip(
              label: Text(_selectedLabels.isEmpty ? 'All stages (${labels.length})' : 'All stages'),
              selected: _selectedLabels.isEmpty,
              onSelected: (_) => setState(() => _selectedLabels.clear()),
            ),
            ...labels.map((label) => FilterChip(
              label: Text(label),
              selected: _selectedLabels.contains(label),
              onSelected: (checked) => setState(() {
                if (checked) {
                  _selectedLabels.add(label);
                } else {
                  _selectedLabels.remove(label);
                }
              }),
            )),
          ]),
        ],
        const SizedBox(height:18),
        if(sources.isEmpty)_empty(context,'No production sheets found','Open Data Sources and load the Cutting and Sewing Google Sheets first.')
        else ...[
          Wrap(spacing:12,runSpacing:12,children:[
            _metric(context,'Total quantity',_fmt(total),Icons.inventory_2_outlined,c.primary),
            _metric(context,'Average quantity',_fmt(average),Icons.functions_rounded,c.secondary),
            _metric(context,'Peak quantity',_fmt(peak),Icons.trending_up_rounded,c.tertiary),
            _metric(context,'Lowest quantity',_fmt(lowest),Icons.trending_down_rounded,c.error),
            _metric(context,'Matching rows','${filtered.length}',Icons.table_rows_rounded,c.tertiary),
            _metric(context,'Stages','${selected.map(_label).toSet().length}',Icons.account_tree_outlined,c.secondary),
          ]),
          const SizedBox(height:18),_title(context,'Quantity trend',Icons.show_chart_rounded),const SizedBox(height:12),
          Card(elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20),side:BorderSide(color:c.outlineVariant)),child:Padding(padding:const EdgeInsets.all(16),child:graph.isEmpty
            ?_empty(context,'No matching date and quantity rows','Check the selected headers or choose All dates. Only real numeric quantities with readable dates are plotted.')
            :Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              SizedBox(height:250,width:double.infinity,child:CustomPaint(painter:_LinePainter(points:graph,line:c.primary,grid:c.outlineVariant,text:c.onSurfaceVariant))),
              const SizedBox(height:8),Text('X-axis: $_group · Y-axis: summed quantity',style:theme.textTheme.bodySmall?.copyWith(color:c.onSurfaceVariant))
            ]))),
          const SizedBox(height:18),_title(context,'Anomaly detection',Icons.warning_amber_rounded),const SizedBox(height:12),
          Card(elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),side:BorderSide(color:c.outlineVariant)),child:Padding(padding:const EdgeInsets.all(16),child:anomalies.isEmpty
            ?Row(children:[Icon(Icons.check_circle_outline,color:c.tertiary),const SizedBox(width:10),Expanded(child:Text(graph.length<4?'Need at least 4 time periods to detect unusual changes.':'No unusual quantity spikes or drops detected.',style:theme.textTheme.bodyMedium))])
            :Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('${anomalies.length} unusual period(s) detected',style:theme.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)),
              const SizedBox(height:8),
              ...anomalies.take(8).map((entry)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Icon(entry.value>graphAverage?Icons.trending_up_rounded:Icons.trending_down_rounded,color:entry.value>graphAverage?c.tertiary:c.error,size:20),
                const SizedBox(width:8),
                Expanded(child:Text('${_date(entry.key)} · ${_fmt(entry.value)} quantity — ${entry.value>graphAverage?'above':'below'} usual level',style:theme.textTheme.bodyMedium))
              ])))
            ]))),
          const SizedBox(height:18),_title(context,'Bottleneck analysis',Icons.account_tree_rounded),const SizedBox(height:12),
          Card(elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),side:BorderSide(color:c.outlineVariant)),child:Padding(padding:const EdgeInsets.all(16),child:bottlenecks.isEmpty
            ?Text('No stage quantity data available for comparison.',style:theme.textTheme.bodyMedium)
            :Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Lowest output: ${bottlenecks.first.key} · ${_fmt(bottlenecks.first.value)}',style:theme.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)),
              const SizedBox(height:8),
              ...bottlenecks.reversed.take(8).toList().reversed.map((entry)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[
                Expanded(flex:3,child:Text(entry.key,overflow:TextOverflow.ellipsis)),
                Expanded(flex:4,child:ClipRRect(borderRadius:BorderRadius.circular(5),child:LinearProgressIndicator(value:bottlenecks.last.value<=0?0:(entry.value/bottlenecks.last.value).clamp(0.0,1.0),minHeight:8))),
                const SizedBox(width:10),
                Text(_fmt(entry.value),style:theme.textTheme.bodySmall)
              ])))
            ]))),
          const SizedBox(height:18),_title(context,'Timeline records',Icons.view_timeline_rounded),const SizedBox(height:12),
          if(filtered.isNotEmpty)Card(elevation:0,clipBehavior:Clip.antiAlias,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),side:BorderSide(color:c.outlineVariant)),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
            headingRowColor:WidgetStatePropertyAll(c.primaryContainer.withValues(alpha:.7)),
            columns:const [DataColumn(label:Text('Date')),DataColumn(label:Text('Stage / Sheet')),DataColumn(label:Text('Quantity'),numeric:true),DataColumn(label:Text('Date field')),DataColumn(label:Text('Quantity field'))],
            rows:filtered.reversed.take(100).map((p)=>DataRow(cells:[DataCell(Text(_date(p.date))),DataCell(Text(p.source)),DataCell(Text(_fmt(p.qty))),DataCell(Text(p.dateField)),DataCell(Text(p.qtyField))])).toList(),
          ))),
          if(filtered.length>100)Padding(padding:const EdgeInsets.all(8),child:Text('Showing latest 100 of ${filtered.length} rows.',style:theme.textTheme.bodySmall))
        ]
      ]),
    );
  }

  List<MapEntry<String,double>> _stageTotals(List<_Point> points) {
    final totals=<String,double>{};
    for(final point in points) {
      totals[point.source]=(totals[point.source]??0)+point.qty;
    }
    final entries=totals.entries.toList()..sort((a,b)=>a.value.compareTo(b.value));
    return entries;
  }

  List<MapEntry<DateTime,double>> _detectAnomalies(List<MapEntry<DateTime,double>> points) {
    if (points.length < 4) return const [];
    final values=points.map((p)=>p.value).toList();
    final mean=values.reduce((a,b)=>a+b)/values.length;
    final variance=values.map((v)=>(v-mean)*(v-mean)).reduce((a,b)=>a+b)/values.length;
    final deviation=Math.sqrt(variance);
    if (deviation==0) return const [];
    // Flag periods at least two standard deviations from the mean.
    return points.where((p)=>(p.value-mean).abs()>=2*deviation)
      .map((p)=>MapEntry(p.key,p.value))
      .toList();
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
  static String? _best(List<String> cols,List<String> aliases){
    for(final a in aliases){for(final c in cols){if(_norm(a)==_norm(c))return c;}}
    for(final c in cols){if(aliases==_dateAliases&&_isDateField(c))return c;if(aliases==_qtyAliases&&_isQtyField(c))return c;}
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

  Widget _drop(BuildContext context,String label,String value,List<String> options,ValueChanged<String> change){
    final c=Theme.of(context).colorScheme;final unique=options.toSet().toList();final safe=unique.contains(value)?value:unique.first;
    return DropdownButtonFormField<String>(initialValue:safe,isExpanded:true,decoration:InputDecoration(labelText:label,filled:true,fillColor:c.surfaceContainerHighest.withValues(alpha:.35),contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:12),border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))),items:unique.map((s)=>DropdownMenuItem(value:s,child:Text(s,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v){if(v!=null)change(v);});
  }
  Widget _title(BuildContext context,String title,IconData icon){final c=Theme.of(context).colorScheme;return Row(children:[Container(width:4,height:26,decoration:BoxDecoration(color:c.primary,borderRadius:BorderRadius.circular(4))),const SizedBox(width:10),Icon(icon,color:c.tertiary),const SizedBox(width:8),Text(title,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800))]);}
  Widget _metric(BuildContext context, String title, String value, IconData icon, Color color) {
    final c = Theme.of(context).colorScheme;
    return SizedBox(
      width: 210,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _empty(BuildContext context,String title,String message){final c=Theme.of(context).colorScheme;return Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.query_stats_rounded,size:42,color:c.tertiary),const SizedBox(height:12),Text(title,textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:8),Text(message,textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodyMedium?.copyWith(color:c.onSurfaceVariant))]));}
}

class _Point {
  const _Point(this.date,this.qty,this.source,this.dateField,this.qtyField);
  final DateTime date;final double qty;final String source,dateField,qtyField;
}

class _LinePainter extends CustomPainter {
  const _LinePainter({required this.points,required this.line,required this.grid,required this.text});
  final List<MapEntry<DateTime,double>> points;final Color line,grid,text;
  @override
  void paint(Canvas canvas,Size size){
    if(points.isEmpty)return;
    const l=48.0,r=10.0,t=12.0,b=32.0;
    final rect=Rect.fromLTRB(l,t,size.width-r,size.height-b);if(rect.width<=0||rect.height<=0)return;
    final max=points.map((p)=>p.value).fold<double>(0,(a,v)=>a>v?a:v);final cap=max<=0?1.0:max*1.12;
    final tp=TextPainter(textDirection:TextDirection.ltr,maxLines:1);final style=TextStyle(color:text,fontSize:10);final gp=Paint()..color=grid..strokeWidth=1;
    for(var i=0;i<=4;i++){final y=rect.bottom-rect.height*i/4;canvas.drawLine(Offset(rect.left,y),Offset(rect.right,y),gp);final v=cap*i/4;tp.text=TextSpan(text:v>=1000?'${(v/1000).toStringAsFixed(1)}k':v.toStringAsFixed(v<10?1:0),style:style);tp.layout();tp.paint(canvas,Offset(0,y-tp.height/2));}
    final path=Path(),area=Path();final paint=Paint()..color=line..strokeWidth=2.8..style=PaintingStyle.stroke..strokeJoin=StrokeJoin.round..strokeCap=StrokeCap.round;
    final fill=Paint()..color=line.withValues(alpha:.12);
    for(var i=0;i<points.length;i++){final x=points.length==1?rect.center.dx:rect.left+rect.width*i/(points.length-1);final y=rect.bottom-points[i].value/cap*rect.height;if(i==0){path.moveTo(x,y);area.moveTo(x,rect.bottom);area.lineTo(x,y);}else{path.lineTo(x,y);area.lineTo(x,y);}}
    area.lineTo(points.length==1?rect.center.dx:rect.right,rect.bottom);area.close();canvas.drawPath(area,fill);canvas.drawPath(path,paint);
    final dot=Paint()..color=line;for(var i=0;i<points.length;i++){final x=points.length==1?rect.center.dx:rect.left+rect.width*i/(points.length-1);final y=rect.bottom-points[i].value/cap*rect.height;canvas.drawCircle(Offset(x,y),3.5,dot);}
    final ids=points.length<=5?List<int>.generate(points.length,(i)=>i):<int>[0,points.length~/2,points.length-1];
    for(final i in ids){final d=points[i].key;tp.text=TextSpan(text:'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}',style:style);tp.layout();final x=points.length==1?rect.center.dx-tp.width/2:(rect.left+rect.width*i/(points.length-1)-tp.width/2).clamp(rect.left,rect.right-tp.width);tp.paint(canvas,Offset(x.toDouble(),rect.bottom+8));}
  }
  @override
  bool shouldRepaint(covariant _LinePainter old)=>old.points!=points||old.line!=line||old.grid!=grid||old.text!=text;
}
