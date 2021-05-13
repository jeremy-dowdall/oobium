Routing (configuration - generated)

Routes?

RouteParser

RouteReference

Route?

RouteData?


router engine
  AppRoute get route -> _route
  set route(AppRoute value) -> _route = value

  String get location -> _route.location
  set location(String value) -> _route = parseLocation(value)
 
AppRoute parseLocation(location)
  path = parsePath(location)
  routeDef = getDefinition(path)
  route = createRoute(location)
  

