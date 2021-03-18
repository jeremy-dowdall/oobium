# oobium_routing
Simplified routing for Flutter's Navigator 2.0.

Type-safe and semi-declarative. Handles the browser address bar for web clients.

## Example
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
	)

runApp(MaterialApp.router(
	title: 'NavDemo',
	routeInformationParser: routes.createRouteParser(),
	routerDelegate: routes.createRouterDelegate()
));

...

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
```
