x-on allows you to easily run code on dispatched DOM events.

Here's an example of simple button that shows an alert when clicked.

`<button x-on:click="alert('Hello World!')">Say Hi</button>`
> x-on can only listen for events with lower case names, as HTML attributes are case-insensitive. Writing x-on:CLICK will listen for an event named click. If you need to listen for a custom event with a camelCase name, you can use the .camel helper to work around this limitation. Alternatively, you can use x-bind to attach an x-on directive to an element in javascript code (where case will be preserved)
