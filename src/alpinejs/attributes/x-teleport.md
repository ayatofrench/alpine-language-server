The `x-teleport` directive allows you to transport part of your Alpine template to another part of the DOM on the page entirely.

This is useful for things like modals (especially nesting them), where it's helpful to break out of the z-index of the current Alpine component.

> Warning: if you are a Livewire user, this functionality does not currently work inside Livewire components. Support for this is on the roadmap.
