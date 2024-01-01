Alpine's x-for directive allows you to create DOM elements by iterating through a list. Here's a simple example of using it to create a list of colors based on an array.

```
<ul x-data="{ colors: ['Red', 'Orange', 'Yellow'] }">
    <template x-for="color in colors">
        <li x-text="color"></li>
    </template>
</ul>
```
- Red
- Orange
- Yellow
There are two rules worth noting about `x-for`:

`x-for` MUST be declared on a `<template>` element That `<template>` element MUST contain only one root element
