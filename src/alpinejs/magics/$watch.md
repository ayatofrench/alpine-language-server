You can "watch" a component property using the $watch magic method. For example:

```
<div x-data="{ open: false }" x-init="$watch('open', value => console.log(value))">
    <button @click="open = ! open">Toggle Open</button>
</div>
```
In the above example, when the button is pressed and open is changed, the provided callback will fire and console.log the new value:

You can watch deeply nested properties using "dot" notation

```
<div x-data="{ foo: { bar: 'baz' }}" x-init="$watch('foo.bar', value => console.log(value))">
    <button @click="foo.bar = 'bob'">Toggle Open</button>
</div>
```
When the <button> is pressed, foo.bar will be set to "bob", and "bob" will be logged to the console.


[ALPINE REFERENCE](https://alpinejs.dev/magics/watch)
