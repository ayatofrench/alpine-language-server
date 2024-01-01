`x-ref` in combination with `$refs` is a useful utility for easily accessing DOM elements directly. It's most useful as a replacement for APIs like `getElementById` and `querySelector`.

```
<button @click="$refs.text.remove()">Remove Text</button>
 
<span x-ref="text">Hello 👋</span>
```
