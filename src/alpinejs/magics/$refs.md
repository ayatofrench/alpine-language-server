$refs is a magic property that can be used to retrieve DOM elements marked with x-ref inside the component. This is useful when you need to manually manipulate DOM elements. It's often used as a more succinct, scoped, alternative to document.querySelector.

```
<button @click="$refs.text.remove()">Remove Text</button>
 
<span x-ref="text">Hello 👋</span>
```

Now, when the <button> is pressed, the <span> will be removed.


[ALPINE REFERENCE](https://alpinejs.dev/magics/refs)
