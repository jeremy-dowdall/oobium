# oobium_routing
[![pub package](https://img.shields.io/pub/v/oobium_routing.svg)](https://pub.dev/packages/oobium_routing)

Simplified routing for Flutter's Navigator 2.0.

- type-safe
- semi-declarative
- browser address bar (bidi)
- nested routers

# Usage
To use this plugin, add `oobium_routing` as a [dependency in your pubspec.yaml file](https://flutter.dev/platform-plugins/).

# Example
```dart
final routes = AppRoutes()
	..add<AuthorsRoute>(
		path: '/authors',
		onParse: (data) => AuthorsRoute(),
		onBuild: (route) => [AuthorsPage()]
	)
	..add<BooksRoute>(
		path: '/books',
		onParse: (data) => BooksRoute(),
		onBuild: (route) => [BooksPage()]
	);

runApp(MaterialApp.router(
	title: 'NavDemo',
	routeInformationParser: routes.createRouteParser(),
	routerDelegate: routes.createRouterDelegate()
));

...

class ExampleView extends StatelessWidget {

	Widget build(BuildContext context) {
		return Center(child: Row(children: [
			ElevatedButton(
				child: Text('Authors'),
				onPressed: () => context.route = AuthorsRoute(),
			),
			ElevatedButton(
				child: Text('Books'),
				onPressed: () => context.route = BooksRoute(),
			),
			ElevatedButton.icon(
				icon: Icon(Icons.arrow_back),
				label: Text('Back'),
				onPressed: () => Navigator.pop(context),
			),
		],),);
	}
}
```
