import 'dart:async';

import 'package:oobium_server/src/server.dart';

class ServiceRegistry {
  
  final _services = <Type, Service2>{};
  final _listeners = <Type, List<Type>>{};
  
  void add(Service2 service) {
    final st = service.runtimeType;
    final ht = service.hostType;
    assert(ht != null);
    assert(!_services.containsKey(st));
    service.services.._registry = this.._service = service;
    _services[st] = service;
    _listeners.putIfAbsent(ht, () => <Type>[]).add(st);
  }
  
  T get<T extends Service2>() => _services[T];
 
  void _attach(Service2 service) {
    if(_listeners.containsKey(service.runtimeType)) {
      for(var listener in _listeners[service.runtimeType]) {
        _services[listener].onAttach(service);
      }
    }
  }
  void _detach(Service2 service) {
    if(_listeners.containsKey(service.runtimeType)) {
      for(var listener in _listeners[service.runtimeType]) {
        _services[listener].onDetach(service);
      }
    }
  }
  
  Future<void> start() => Future.forEach<Service2>(_services.values, (service) => service.onStart());
  Future<void> stop() => Future.forEach<Service2>(_services.values, (service) => service.onStop());
}

class Services {
  Service2 _service;
  ServiceRegistry _registry;

  void attach() => _registry._attach(_service);
  void detach() => _registry._detach(_service);
  T get<T extends Service2>() => _registry.get<T>();
}

abstract class Service2<H> {
  
  final services = Services();
  Type get hostType => H;

  void onAttach(H host)    {}
  void onDetach(H host)    {}
  FutureOr<void> onStart() => Future.value();
  FutureOr<void> onStop()  => Future.value();

}

class HostService extends Service2<Host> {
  final Host host;
  HostService(this.host);
}

abstract class Service<H, S extends Service<H,S>> {

  void onAttach(H host)    {}
  void onDetach(H host)    {}
  FutureOr<void> onStart() => Future.value();
  FutureOr<void> onStop()  => Future.value();

  final _services = <Service<S, dynamic>>[];
  void add(Service<S, dynamic> service) {
    _services.add(service);
  }

  bool _attached = false;
  bool get isAttached => _attached;
  bool get isNotAttached => !isAttached;

  void attachServices() {
    if(isNotAttached) {
      _attached = true;
      for(var service in _services) { service.onAttach(this); }
    }
  }

  void detachServices() {
    if(isAttached) {
      _attached = false;
      for(var service in _services) { service.onDetach(this); }
    }
  }

  bool _started = false;
  bool get isStarted => _started;
  bool get isNotStarted => !isStarted;

  FutureOr<void> start() {
    if(isNotStarted) {
      _started = true;
      return Future.forEach([...?_services, this], (service) => service.start());
    }
    return Future.value();
  }

  FutureOr<void> stop() {
    if(isStarted) {
      _started = false;
      return Future.forEach([...?_services, this], (service) => service.stop);
    }
    return Future.value();
  }
}
