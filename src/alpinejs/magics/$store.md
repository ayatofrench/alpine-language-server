You can use $store to conveniently access global Alpine stores registered using Alpine.store(...). For example:

```
<button x-data @click="$store.darkMode.toggle()">Toggle Dark Mode</button>
 
...
 
<div x-data :class="$store.darkMode.on && 'bg-black'">
    ...
</div>
 
 
<script>
    document.addEventListener('alpine:init', () => {
        Alpine.store('darkMode', {
            on: false,
 
            toggle() {
                this.on = ! this.on
            }
        })
    })
</script>
```

Given that we've registered the darkMode store and set on to "false", when the <button> is pressed, on will be "true" and the background color of the page will change to black.


[ALPINE REFERENCE](https://alpinejs.dev/magics/store)
