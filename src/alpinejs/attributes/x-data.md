Everything in Alpine starts with the x-data directive.

`x-data` defines a chunk of HTML as an Alpine component and provides the reactive data for that component to reference.

Here's an example of a contrived dropdown component:

```
<div x-data="{ open: false }">
    <button @click="open = ! open">Toggle Content</button>
 
    <div x-show="open">
        Content...
    </div>
</div>
```

Don't worry about the other directives in this example (@click and x-show), we'll get to those in a bit. For now, let's focus on x-data.
