---
title: Some Vue Basics
date: 2024-02-18 00:00:00
categories: Frontend
description: Some basic concepts of Vue3 including component registration, ref, reactivity, lifecycle, watch, and event flow
tags:
- Vue
- JavaScript
---

## 1. Global Component Registration

In Vue, components can be registered globally or locally.

### Global Registration

Example:

```javascript
import { createApp } from 'vue'
import App from './App.vue'
import TodoDeleteButton from './components/TodoDeleteButton.vue'

const app = createApp(App)

app.component('TodoDeleteButton', TodoDeleteButton)

app.mount('#app')
```

This registers the component globally.  
After that, the component can be used anywhere in the application.

Example:

```vue
<template>
  <TodoDeleteButton />
</template>
```

No need to import or register the component again.

---

### Local Registration

If a component is only used in one place, local registration is preferred.

```vue
<script setup>
import TodoDeleteButton from '@/components/TodoDeleteButton.vue'
</script>

<template>
  <TodoDeleteButton />
</template>
```

This avoids registering unnecessary global components.

---

## 2. `ref` and `ref.value`

In Vue's Composition API, `ref()` creates a reactive reference.

Example:

```javascript
const count = ref(0)
```

Internally this is:

```javascript
{ value: 0 }
```

### In Template

Vue automatically unwraps refs inside templates.

```vue
<template>
  <button @click="count++">Count is: {{ count }}</button>
</template>
```

No need to write `.value`.

---

### In JavaScript

You **must** access the value using `.value`.

```javascript
count.value++
```

Otherwise you would be modifying the object instead of the value.

---

## 3. `<script setup>` Behavior

Variables declared in `<script setup>` are automatically available in the template.

Example:

```vue
<script setup>
const message = "Hello Vue"
</script>

<template>
  {{ message }}
</template>
```

No additional export or return is needed.

---

## 4. Vue Reactivity: `reactive()`

`reactive()` converts an object into a reactive proxy.

Example:

```javascript
const raw = {}
const proxy = reactive(raw)

console.log(proxy === raw) // false
```

The returned value is a **Proxy**.

Important rule:

Only the proxy is reactive.  
Mutating the original object will not trigger updates.

```javascript
proxy.name = "Alice" // reactive
raw.name = "Bob"     // not reactive
```

Vue always returns the same proxy for the same object:

```javascript
reactive(raw) === proxy // true
reactive(proxy) === proxy // true
```

Nested objects are also reactive due to **deep reactivity**.

---

## 5. `computed()`

`computed()` creates a computed reactive value.

Example:

```javascript
const publishedBooksMessage = computed(() => {
  return author.books.length > 0 ? 'Yes' : 'No'
})
```

Computed values behave like refs:

```javascript
publishedBooksMessage.value
```

But inside templates `.value` is automatically unwrapped.

---

## 6. Arrow Function Returning Objects

When returning an object in an arrow function, parentheses are required.

Correct:

```javascript
const getObj = () => ({ name: "Vue", version: 3 })
```

Incorrect:

```javascript
const getObj = () => { name: "Vue" }
```

Because `{}` is interpreted as a code block instead of an object.

---

## 7. `v-if` vs `v-show`

Both are used for conditional rendering.

### `v-if`

- The element is **actually created and destroyed**
- Lazy rendering
- Higher toggle cost

### `v-show`

- The element is always rendered
- Visibility controlled via CSS (`display`)
- Higher initial render cost

General rule:

| Scenario | Recommended |
|--------|------|
| Frequent toggling | `v-show` |
| Rarely changes | `v-if` |

---

## 8. Event Flow in the DOM

DOM events have three phases:

1. **Capture Phase**  
   Event travels from outer elements to the target.

2. **Target Phase**  
   Event reaches the target element.

3. **Bubble Phase**  
   Event propagates from the target back outward.

Default Vue event listeners run in the **bubble phase**.

Example:

```vue
<button @click="handleClick">Click</button>
```

To handle the event during the capture phase:

```vue
<button @click.capture="handleClick">Click</button>
```

Summary:

| Phase | Direction |
|------|------|
| Capture | outer → inner |
| Target | target element |
| Bubble | inner → outer |

---

## 9. `reactive` vs `watch`

### `reactive`

Makes an object and all nested properties reactive.

Example:

```javascript
const obj = reactive({
  user: {
    name: "Alice",
    age: 20
  }
})

obj.user.name = "Bob"
```

Any change automatically updates the view.

---

### `watch`

`watch` observes specific reactive data.

Example:

```javascript
watch(
  () => obj.user,
  (newVal, oldVal) => {
    console.log("User object changed")
  }
)
```

By default it only detects **reference changes**.

```javascript
obj.user = { name: "Bob" } // triggers
obj.user.name = "Charlie"  // does NOT trigger
```

To watch nested properties:

```javascript
watch(
  () => obj.user,
  () => {
    console.log("User changed")
  },
  { deep: true }
)
```

---

## 10. `watch` vs `watchEffect`

### `watch`

Requires an explicit getter.

```javascript
watch(() => props.foo, (newVal) => {
  console.log(newVal)
})
```

### `watchEffect`

Automatically tracks dependencies.

```javascript
watchEffect(() => {
  console.log(props.foo)
})
```

Difference:

| Feature | watch | watchEffect |
|------|------|------|
| dependency control | manual | automatic |
| flexibility | higher | simpler |

---

## 11. Props Binding

If you do not use `:` (or `v-bind:`), Vue treats the value as a static string.

Static example:

```vue
<BlogPost title="My Static Title" />
```

Dynamic binding:

```vue
<BlogPost :title="post.title" />
```

Using `:` makes the value reactive.

If `post.title` changes, the component updates automatically.

---

## Summary

Some key Vue concepts include:

- component registration (global vs local)
- `ref` and reactive data
- `reactive()` proxies
- `computed()` properties
- `watch` and `watchEffect`
- event propagation
- conditional rendering (`v-if` vs `v-show`)
- props binding

Understanding these fundamentals makes it much easier to build Vue applications effectively.