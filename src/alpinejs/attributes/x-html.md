x-html sets the "innerHTML" property of an element to the result of a given expression.

⚠️ Only use on trusted content and never on user-provided content. ⚠️ Dynamically rendering HTML from third parties can easily lead to XSS vulnerabilities.

Here's a basic example of using x-html to display a user's username.

```
<div x-data="{ username: '<strong>calebporzio</strong>' }">
    Username: <span x-html="username"></span>
</div>
```
> Username: calebporzio
Now the <span> tag's inner HTML will be set to "calebporzio".
