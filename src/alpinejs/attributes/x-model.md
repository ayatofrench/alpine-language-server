`x-model` allows you to bind the value of an input element to Alpine data.

Here's a simple example of using `x-model` to bind the value of a text field to a piece of data in Alpine.

```
<div x-data="{ message: '' }">
    <input type="text" x-model="message">
 
    <span x-text="message">
</div>
```
Now as the user types into the text field, the message will be reflected in the `<span>` tag.

`x-model` is two-way bound, meaning it both "sets" and "gets". In addition to changing data, if the data itself changes, the element will reflect the change.

We can use the same example as above but this time, we'll add a button to change the value of the message property.

```
<div x-data="{ message: '' }">
    <input type="text" x-model="message">
 
    <button x-on:click="message = 'changed'">Change Message</button>
</div>
```
Now when the `<button>` is clicked, the input element's value will instantly be updated to "changed".

`x-model` works with the following input elements:

- `<input type="text">`
- `<textarea>`
- `<input type="checkbox">`
- `<input type="radio">`
- `<select>`
