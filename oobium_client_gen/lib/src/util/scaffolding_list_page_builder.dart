import 'package:oobium_client_gen/src/util/model_field.dart';
import 'package:oobium_client_gen/src/util/scaffolding_model.dart';

class ScaffoldingListPageBuilder {

  final Iterable<ScaffoldingModel> models;
  ScaffoldingListPageBuilder(this.models);

  String build() => '''
    enum ScaffoldingListView {
      ${models.map((model) => model.listViewName).join(',\n')}
    }
    
    class ScaffoldingDrawer extends StatelessWidget {
    
      @override
      Widget build(BuildContext context) {
        return Drawer(
          child: ListView(
            children: [
              DrawerHeader(child: Text('Oobium Models')),
              ...drawerItems(context)
            ],
          ),
        );
      }
    
      List<Widget> drawerItems(BuildContext context) => [
        ${models.map((model) => buildDrawerItem(model)).join(',\n')}
      ];
    
      navigateTo(BuildContext context, ScaffoldingListView view) {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => ScaffoldingPage(view)));
      }
    }

    class ScaffoldingPage extends StatelessWidget {

      final ScaffoldingListView initialView;
      ScaffoldingPage([this.initialView = ScaffoldingListView.Users]);
    
      @override
      Widget build(BuildContext context) {
        return ChangeNotifierProvider(
          create: (context) => ScaffoldingModel(initialView),
          builder: (context, _) {
            final model = context.watch<ScaffoldingModel>();
            return Scaffold(
              appBar: AppBar(
                title: Text(model.selectedLabel),
                actions: [
                  ActionButton(
                    label: 'Exit',
                    onPressed: (_) => Navigator.pop(context)
                  )
                ],
              ),
              drawer: Drawer(
                child: ListView(
                  children: [
                    DrawerHeader(child: Text('Models')),
                    ...drawerItems(context, model)
                  ],
                ),
              ),
              body: scaffoldingListView(model.selected),
              floatingActionButton: FloatingActionButton(
                child: Icon(Icons.add),
                onPressed: () => createModel(context, model.selected),
              ),
            );
          },
        );
      }

      createModel(BuildContext context, ScaffoldingListView selected) {
        switch(selected) {
          ${models.map((model) => 'case ScaffoldingListView.${model.listViewName}: Navigator.push(context, MaterialPageRoute(builder: (context) => ${model.detailView}.createNew())); break;').join('\n')}
        }
        return ${models.first.listView}();
      }

      List<Widget> drawerItems(BuildContext context, ScaffoldingModel model) => [
        ${models.map((model) => buildListViewDrawerItem(model)).join(',\n')}
      ];
      
      Widget scaffoldingListView(ScaffoldingListView selected) {
        switch(selected) {
          ${models.map((model) => 'case ScaffoldingListView.${model.listViewName}: return ${model.listView}();').join('\n')}
        }
        return ${models.first.listView}();
      }
    }

    class ScaffoldingModel extends ChangeNotifier {

      ScaffoldingModel(ScaffoldingListView initialView) {
        _selected = initialView ?? ScaffoldingListView.${models.first.listViewName};
      }
    
      ScaffoldingListView _selected;
      ScaffoldingListView get selected => _selected;
      set selected(ScaffoldingListView value) {
        _selected = value;
        notifyListeners();
      }
      
      String get selectedLabel {
        switch(_selected) {
          ${models.map((model) => 'case ScaffoldingListView.${model.listViewName}: return \'${model.listViewLabel}\';\n').join()}
        }
        return '${models.first.listViewLabel}';
      }
    }

    ${models.map((model) => buildListView(model)).join('\n')}
  ''';

  String buildDrawerItem(ScaffoldingModel model) {
    return '''
      ListTile(
        title: Text('${model.listViewLabel}'),
        onTap: () => navigateTo(context, ScaffoldingListView.${model.listViewName}),
      )
    ''';
  }

  String buildListViewDrawerItem(ScaffoldingModel model) {
    return '''
      ListTile(
        leading: model.selected == ScaffoldingListView.${model.listViewName} ? Icon(Icons.check) : null,
        title: Text('${model.listViewLabel}'),
        onTap: () {
          model.selected = ScaffoldingListView.${model.listViewName};
          Navigator.pop(context);
        }
      )
    ''';
  }

  String buildListView(ScaffoldingModel model) => '''
    class ${model.listView} extends StatelessWidget {

      final HasMany<${model.type}> hasMany;
      ${model.listView}([this.hasMany]);
      
      @override
      Widget build(BuildContext context) {
        return ChangeNotifierProvider(
          create: (context) => ${model.listModel}(context.modelContext, hasMany),
          builder: (context, _) {
            final model = context.watch<${model.listModel}>();
            if(model.isLoading) {
              return ListTile(title: Text('loading'),);
            }
            if(model.${model.modelsVarName}.isEmpty) {
              return ListTile(title: Text('No ${model.modelsVarName} found'),);
            }
            return ListView.builder(
              itemCount: model.${model.modelsVarName}.length,
              itemBuilder: (context, index) {
                final ${model.modelVarName} = model.${model.modelsVarName}[index];
                return ListTile(
                  title: Text(\'\$\{${model.modelVarName}.${model.titleField.name}}\'.isBlank ? '${model.name} - \$\{${model.modelVarName}.id\}' : \'\$\{${model.modelVarName}.${model.titleField.name}}\'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ${model.detailView}(${model.modelVarName}.link)))
                );
              },
            );
          },
        );
      }
    }
    
    class ${model.listModel} extends ChangeNotifier {
    
      StreamSubscription _subscription;
      ${model.listModel}(ModelContext context, HasMany<${model.type}> hasMany) {
        if(hasMany != null) hasMany.resolved().then((value) => ${model.modelsVarName} = value.models);
        else _subscription = context.streamAll<${model.type}>([]).listen((value) => ${model.modelsVarName} = value);
      }
      
      List<${model.type}> _${model.modelsVarName};
      List<${model.type}> get ${model.modelsVarName} => _${model.modelsVarName};
      set ${model.modelsVarName}(List<${model.type}> value) {
        _${model.modelsVarName} = value;
        notifyListeners();
      }
      
      bool get isLoading => ${model.modelsVarName} == null;
      
      @override
      void dispose() {
        _subscription?.cancel();
        super.dispose();
      }
    }
  ''';
}
