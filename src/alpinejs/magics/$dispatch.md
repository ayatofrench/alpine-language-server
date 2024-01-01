$dispatch is a helpful shortcut for dispatching browser events.

```
<div @notify="alert('Hello World!')">
    <button @click="$dispatch('notify')">
        Notify
    </button>
</div>
```

[ALPINE REFERENCE](https://alpinejs.dev/magics/dispatch)
