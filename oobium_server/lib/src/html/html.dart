import 'package:meta/meta.dart';
import 'package:oobium_server/src/server_settings.dart';

class Page {
  final Page layout;
  final Map<String, List<Element>> blocks;
  Page({this.layout, List<Element> content, List<Element> scripts, List<Element> styles, Map<String, List<Element>> blocks}) : blocks = blocks ?? {} {
    if(content != null) {
      assert(this.blocks.containsKey('content') == false, 'content will shadow blocks[\'content\']');
      this.blocks['content'] = content;
    }
    if(scripts != null) {
      assert(this.blocks.containsKey('scripts') == false, 'scripts will shadow blocks[\'scripts\']');
      this.blocks['scripts'] = scripts;
    }
    if(styles != null) {
      assert(this.blocks.containsKey('styles') == false, 'styles will shadow blocks[\'styles\']');
      this.blocks['styles'] = styles;
    }
    for(var e in this.blocks.values.expand((l) => l ?? <Element>[])) { e._page = this; }
  }

  Page _page;
  String render() {
    final buffer = StringBuffer();
    buffer.write('<!DOCTYPE html>');
    buffer.write('<html itemscope>');
    if(layout == null) {
      renderTo(buffer, content: blocks['content']);
    } else {
      layout._page = this;
      renderTo(buffer, content: layout.blocks['content']);
    }
    buffer.write('</html>');
    return buffer.toString();
  }

  void renderTo(StringBuffer buffer, {List<Element> content}) {
    if(content != null) {
      for (var e in content) { e.renderTo(buffer); }
    }
  }
}

abstract class Element {
  Page _page;
  Element _parent;
  void renderTo(StringBuffer buffer);
  Page get page => _page?._page ?? _page ?? _parent.page;
}

class Link extends Element {
  final String crossorigin;
  final String href;
  final String hreflang;
  final String media;
  final String referrerPolicy;
  final String rel;
  final String sizes;
  final String title;
  final String type;
  Link({this.crossorigin, this.href, this.hreflang, this.media, this.referrerPolicy, this.rel, this.sizes, this.title, this.type});
  @override
  void renderTo(StringBuffer buffer) {
    buffer.write('<link');
    if(crossorigin != null) buffer..write(' crossorigin=\'')..write(crossorigin)..write('\'');
    if(href != null) buffer..write(' href=\'')..write(href)..write('\'');
    if(hreflang != null) buffer..write(' hreflang=\'')..write(hreflang)..write('\'');
    if(media != null) buffer..write(' media=\'')..write(media)..write('\'');
    if(referrerPolicy != null) buffer..write(' referrerpolicy=\'')..write(referrerPolicy)..write('\'');
    if(rel != null) buffer..write(' rel=\'')..write(rel)..write('\'');
    if(sizes != null) buffer..write(' sizes=\'')..write(sizes)..write('\'');
    if(title != null) buffer..write(' title=\'')..write(title)..write('\'');
    if(type != null) buffer..write(' type=\'')..write(type)..write('\'');
    buffer.write('>');
  }
}

class Script extends Element {
  final String type;
  final String src;
  final String content;
  final bool async;
  final bool defer;
  Script({this.type, this.src, this.content, this.async, this.defer});
  @override
  void renderTo(StringBuffer buffer) {
    buffer.write('<script');
    if(type != null) buffer..write(' type=\'')..write(type)..write('\'');
    if(src != null) buffer..write(' src=\'')..write(src)..write('\'');
    if(async == true) buffer..write(' async');
    if(defer == true) buffer..write(' defer');
    if(content != null) { buffer..write('>')..write(content)..write('</script>'); }
    else { buffer.write('></script>'); }
  }
}

class Style extends Element {
  final String media;
  final String type;
  final String content;
  Style({this.media, this.type, this.content});
  @override
  void renderTo(StringBuffer buffer) {
    buffer..write('<style');
    if(media != null) buffer..write(' media=\'')..write(media)..write('\'');
    if(type != null) buffer..write(' type=\'')..write(type)..write('\'');
    buffer..write('>')..write(content)..write('</style>');
  }
}

class Html extends Element {
  final String tag;
  final String text;
  final Map<String, dynamic> attributes;
  final List<Element> children;
  Html({this.tag, this.text, this.attributes, this.children}) {
    if(children != null) for(var e in children) { e._parent = this; }
  }
  @override
  void renderTo(StringBuffer buffer) {
    if(tag != null) {
      buffer..write('<')..write(tag);
      if(attributes != null) for(var k in attributes.keys) { buffer..write(' ')..write(k)..write('=\'')..write(attributes[k])..write('\''); }
      buffer.write('>');
      if(text != null) buffer.write(text);
      if(children != null) for (var child in children) { child.renderTo(buffer); }
      if(tag != null) buffer..write('</')..write(tag)..write('>');
    } else {
      if(children != null) for(var child in children) { child.renderTo(buffer); }
    }
  }
  @override
  String toString() => 'Html($tag)';
}

class Block extends Element {
  final String name;
  final bool optional;
  Block(this.name, {this.optional=false});
  @override
  void renderTo(StringBuffer buffer) {
    final block = page.blocks[name];
    assert(optional || block != null, 'could not find block with name \'$name\'');
    if(block != null) for(var e in block) { e.renderTo(buffer); }
  }
  @override
  String toString() => 'Block($name)';
}

Block block(String name, {bool optional=false}) => Block(name, optional: optional);
Block content({bool optional=false}) => Block('content', optional: optional);
Block scripts({bool optional=true}) => Block('scripts', optional: optional);
Block styles({bool optional=true}) => Block('styles', optional: optional);
Html head(List<Element> children) => Html(tag: 'head', children: children);
Html body(List<Element> children) => Html(tag: 'body', children: children);
Html meta(Map<String, String> attributes) => Html(tag: 'meta', attributes: attributes);
Html title(String text) => Html(tag: 'title', text: text);
Link link({String rel = 'stylesheet', String media, String type, String href, String content}) => Link(href: href, media: media, rel: rel, type: type);
Script script({String type, String src, String content, bool async=false, bool defer=false}) => Script(type: type, src: src, content: content, async: async, defer: defer);
Style style({String media, String type, String content}) => Style(media: media, type: type, content: content);
Html iframe({String src, int frameborder, int width, int height, bool allowFullScreen, String id, List<String> classes, String style, Map<String, dynamic> data, String text, List<Element> children}) => Html(tag: 'iframe', attributes: _attrs(id, classes, style, data, {'src': src, 'frameborder': frameborder, 'width': width, 'height': height, 'allowFullScreen': allowFullScreen}), text: text, children: children);
Html div({String id, List<String> classes, String style, Map<String, dynamic> data, String text, List<Element> children}) => Html(tag: 'div', attributes: _attrs(id, classes, style, data), text: text, children: children);
Html span({String id, List<String> classes, String style, Map<String, dynamic> data, String text, List<Element> children}) => Html(tag: 'span', attributes: _attrs(id, classes, style, data), text: text, children: children);
Html a({@required String href, String id, List<String> classes, String style, Map<String, dynamic> data, String text, List<Element> children}) => Html(tag: 'a', attributes: _attrs(id, classes, style, data, {'href': href}), text: text, children: children);
Html i({String id, List<String> classes, String style, Map<String, dynamic> data, String text, List<Element> children}) => Html(tag: 'i', attributes: _attrs(id, classes, style, data), text: text, children: children);
Html img({@required String src, String id, List<String> classes, String style, Map<String, dynamic> data, String text, List<Element> children}) => Html(tag: 'img', attributes: _attrs(id, classes, style, data, {'src': src}), text: text, children: children);
Html form({String action, bool autocomplete, String enctype, String method, String name, bool novalidate, String rel, String target, String id, List<String> classes, String style, Map<String, dynamic> data, String text, List<Element> children}) => Html(tag: 'form', attributes: _attrs(id, classes, style, data, {
  'action': action, 'autocomplete': (autocomplete == false) ? 'off' : null, 'enctype': enctype, 'method': method, 'name': name, 'novalidate': (novalidate == true) ? 'novalidate' : null, 'rel': rel, 'target': target}), text: text, children: children
);
Html input({
  String accept, String alt, bool autocomplete, bool autofocus, bool checked, bool disabled, String form, String formaction, String formenctype, String formmethod, bool formnovalidate, int height, String list, String max, int maxlength, String min, int minLength, bool multiple, String name, String pattern, String placeholder, bool readonly, bool required, int size, String src, String step, String type, String value, int width,
  String id, List<String> classes, String style, Map<String, dynamic> data, String text, List<Element> children}) => Html(tag: 'input', attributes: _attrs(id, classes, style, data,
    {'accept': accept, 'alt': alt, 'autocomplete': (autocomplete == false) ? 'off' : null, 'autofocus': (autofocus == true) ? 'autofocus' : null, 'checked': (checked == true) ? 'checked' : null, 'disabled': (disabled == true) ? 'disabled' : null, 'form': form, 'formaction': formaction, 'formenctype': formenctype, 'formmethod': formmethod, 'formnovalidate': (formnovalidate == true) ? 'formnovalidate' : null, 'height': height, 'list': list, 'max': max, 'maxlength': maxlength, 'min': min, 'minLength': minLength, 'multiple': (multiple == true) ? 'multiple' : null, 'name': name, 'pattern': pattern, 'placeholder': placeholder, 'readonly': (readonly == true) ? 'readonly' : null, 'required': (required == true) ? 'required' : null, 'size': size, 'src': src, 'step': step, 'type': type, 'value': value, 'width': width,})
);
Html video({
  bool autoplay, bool controls, int height, bool loop, bool muted, String poster, String preload, String src, int width,
  String id, List<String> classes, String style, Map<String, dynamic> data, String text, List<Element> children}) => Html(tag: 'video', attributes: _attrs(id, classes, style, data,
    {'autoplay': (autoplay == true) ? 'autoplay' : null, 'controls': (controls == true) ? 'controls' : null, 'height': height, 'loop': (loop == true) ? 'loop' : null, 'muted': (muted == true) ? 'muted' : null, 'poster': poster, 'preload': preload, 'src': src, 'width': width,}), text: text, children: children
);
Html audio({
  bool autoplay, bool controls, bool loop, bool muted, String preload, String src,
  String id, List<String> classes, String style, Map<String, dynamic> data, String text, List<Element> children}) => Html(tag: 'audio', attributes: _attrs(id, classes, style, data,
    {'autoplay': (autoplay == true) ? 'autoplay' : null, 'controls': (controls == true) ? 'controls' : null, 'loop': (loop == true) ? 'loop' : null, 'muted': (muted == true) ? 'muted' : null, 'preload': preload, 'src': src,}), text: text, children: children
);

Html jquery({bool defer=false, String version='3.5.1'}) => Html(children: [
  script(defer: defer, src: 'https://ajax.googleapis.com/ajax/libs/jquery/$version/jquery.min.js')
]);

Html fileUploader(String action) => Html(children: [
  div(children: [
    form(action: action, enctype: 'multipart/form-data', target: '_blank', children: [
      input(id: 'file', type: 'file', name: 'file'),
      input(type: 'submit'),
    ])
  ])
]);

Html firebase({FirebaseConfig config, String version='8.0.0', bool defer=false,
  bool analytics=false, bool auth=false, bool firestore=false, bool functions=false, bool messaging=false,
  bool storage=false, bool performance=false, bool database=false, bool remoteConfig=false}) => Html(children: [
  // https://firebase.google.com/docs/web/setup#available-libraries
  if(config != null) script(defer: defer, src: 'https://www.gstatic.com/firebasejs/$version/firebase-app.js'),
  if(config != null && analytics) script(defer: defer, src: 'https://www.gstatic.com/firebasejs/$version/firebase-analytics.js'),
  if(config != null && auth) script(defer: defer, src: 'https://www.gstatic.com/firebasejs/$version/firebase-auth.js'),
  if(config != null && firestore) script(defer: defer, src: 'https://www.gstatic.com/firebasejs/$version/firebase-firestore.js'),
  if(config != null && functions) script(defer: defer, src: 'https://www.gstatic.com/firebasejs/$version/firebase-functions.js'),
  if(config != null && messaging) script(defer: defer, src: 'https://www.gstatic.com/firebasejs/$version/firebase-messaging.js'),
  if(config != null && storage) script(defer: defer, src: 'https://www.gstatic.com/firebasejs/$version/firebase-storage.js'),
  if(config != null && performance) script(defer: defer, src: 'https://www.gstatic.com/firebasejs/$version/firebase-performance.js'),
  if(config != null && database) script(defer: defer, src: 'https://www.gstatic.com/firebasejs/$version/firebase-database.js'),
  if(config != null && remoteConfig) script(defer: defer, src: 'https://www.gstatic.com/firebasejs/$version/firebase-remote-config.js'),
  if(config != null) script(defer: defer, content: '''
    firebase.initializeApp({
      apiKey: '${config.apiKey}',
      authDomain: '${config.authDomain}',
      databaseURL: '${config.databaseURL}',
      projectId: '${config.projectId}',
      storageBucket: '${config.storageBucket}',
      messagingSenderId: '${config.messagingSenderId}'
    });
  '''),
]);

Html googleAnalytics({String create, String send, bool production=false}) => Html(children: [
  if(production && create != null && send != null)
    script(content: '''
      (function(i,s,o,g,r,a,m) {
        i['GoogleAnalyticsObject'] = r;
        i[r] = i[r] || function() { (i[r].q = i[r].q || []).push(arguments) };
        i[r].l = 1 * new Date();
        a = s.createElement(o);
        m = s.getElementsByTagName(o)[0];
        a.async = 1;
        a.src = g;
        m.parentNode.insertBefore(a, m);
      })(window, document, 'script', 'https://www.google-analytics.com/analytics.js', 'ga');
      ga('create', '$create', 'auto');
      ga('send', '$send');
    ''')
]);

Html unfurl(String url, String title, String description, String image) => Html(children: [
  // facebook open graph tags
  meta({'property': 'og:type', 'content': 'website'}),
  meta({'property': 'og:url', 'content': url}),
  meta({'property': 'og:title', 'content': title}),
  meta({'property': 'og:description', 'content': description}),
  meta({'property': 'og:image', 'content': image}),

  // twitter card tags additive with the og: tags
  meta({'name': 'twitter:card', 'content': 'summary_large_image'}),
  meta({'name': 'twitter:domain', 'value': 'victoriaschocolates.com'}),
  meta({'name': 'twitter:url', 'value': url}),
  meta({'name': 'twitter:title', 'value': title}),
  meta({'name': 'twitter:description', 'value': description}),
  meta({'name': 'twitter:image', 'content': image}),
]);


Map<String, dynamic> _attrs(String id, List<String> classes, String style, Map<String, dynamic> data, [Map<String, dynamic> others]) {
  final attributes = <String, dynamic>{};
  if(id != null) attributes['id'] = id;
  if(classes != null && classes.isNotEmpty) attributes['class'] = classes.join(' ');
  if(style != null) attributes['style'] = style;
  if(data != null && data.isNotEmpty) for(var k in data.keys) { attributes['data-$k'] = '${data[k]}'; }
  if(others != null && others.isNotEmpty) attributes.addAll(others..removeWhere((k, v) => v == null));
  return attributes;
}
