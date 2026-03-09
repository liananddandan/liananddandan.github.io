---
title: Front End Layout Methods (Flex and Grid)
date: 2024-04-09 00:00:00
categories: Frontend
description: Basic notes on modern front-end layout methods using Flexbox and CSS Grid
tags:
- Flexbox
- Grid
---

## Introduction

Modern front-end layout is mainly built on two powerful systems:

- **Flexbox**
- **CSS Grid**

Both tools greatly simplify layout design compared to older techniques such as floats or positioning.

This note records some basic usage and concepts of these two layout methods.

References:

- https://www.ruanyifeng.com/blog/2015/07/flex-grammar.html
- https://www.ruanyifeng.com/blog/2019/03/grid-layout-tutorial.html

---

# 1. Flex Layout

Flex is short for **Flexible Box Layout**.

It is mainly used for **one-dimensional layout** (either row or column).

To enable flex layout:

```css
.box {
  display: flex;
}
```

Or inline flex:

```css
.box {
  display: inline-flex;
}
```

In Flexbox:

- The parent element is the **flex container**
- Child elements are **flex items**

Flex layout contains two axes:

- **Main axis**
- **Cross axis**

Each axis has start and end points.

---

## flex-direction

Controls the direction of the main axis.

```css
flex-direction: row | row-reverse | column | column-reverse;
```

| Value | Meaning |
|------|------|
| row | horizontal layout |
| column | vertical layout |
| row-reverse | reverse horizontal |
| column-reverse | reverse vertical |

---

## flex-wrap

Controls whether items wrap to multiple lines.

```css
flex-wrap: nowrap | wrap | wrap-reverse;
```

Default behavior is **nowrap**.

`wrap-reverse` places the first row below later rows.

---

## flex-flow

Shorthand property.

```css
flex-flow: <flex-direction> <flex-wrap>;
```

Example:

```css
flex-flow: row wrap;
```

---

## justify-content

Controls alignment along the **main axis**.

```css
justify-content:
  flex-start |
  flex-end |
  center |
  space-between |
  space-around;
```

---

## align-items

Controls alignment along the **cross axis**.

```css
align-items:
  flex-start |
  flex-end |
  center |
  baseline |
  stretch;
```

---

## align-content

Used when there are **multiple rows**.

```css
align-content:
  flex-start |
  flex-end |
  center |
  space-between |
  space-around |
  stretch;
```

---

## Flex Item Properties

Properties applied to individual flex items.

### order

Controls the order of items.

```css
order: 1;
```

---

### flex-grow

Defines how much an item grows relative to others.

---

### flex-shrink

Defines how much an item shrinks when space is limited.

---

### flex-basis

Defines the initial size of an item.

---

### flex (shorthand)

```css
flex: <flex-grow> <flex-shrink> <flex-basis>;
```

Example:

```css
flex: 1;
```

---

### align-self

Overrides the container's alignment for a single item.

```css
align-self: center;
```

---

# 2. Grid Layout

Grid layout is designed for **two-dimensional layout**.

Compared with Flexbox, Grid can control both rows and columns simultaneously.

Enable grid layout:

```css
.container {
  display: grid;
}
```

Or inline grid:

```css
.container {
  display: inline-grid;
}
```

The parent element becomes a **grid container**, and its children are **grid items**.

---

## grid-template-columns / grid-template-rows

Defines column and row sizes.

Example:

```css
grid-template-columns: 100px 100px 100px;
grid-template-rows: 100px 100px 100px;
```

Percentage example:

```css
grid-template-columns: 33.33% 33.33% 33.33%;
```

Using repeat:

```css
grid-template-columns: repeat(3, 1fr);
```

Example with different sizes:

```css
grid-template-columns: 150px 1fr 2fr;
```

---

## auto-fill

Allows the grid to automatically fill rows or columns.

```css
grid-template-columns: repeat(auto-fill, 100px);
```

This allows the layout to adapt when the container width changes.

---

## fr Unit

`fr` means **fraction of available space**.

Example:

```css
grid-template-columns: 1fr 1fr;
```

This splits the container evenly.

---

## Grid Gap

Controls spacing between grid items.

```css
grid-row-gap: 20px;
grid-column-gap: 20px;
```

Shorthand:

```css
grid-gap: 20px;
```

---

## grid-auto-flow

Controls automatic item placement.

```css
grid-auto-flow: row;
grid-auto-flow: column;
grid-auto-flow: row dense;
```

`dense` tries to fill empty spaces.

---

## Item Alignment

### justify-items / align-items

Control alignment of individual grid items.

---

### justify-content / align-content

Control alignment of the **entire grid**.

---

### justify-self / align-self

Override alignment for a specific item.

---

# Flex vs Grid

Both systems are useful but designed for different scenarios.

| Layout Type | Recommended Tool |
|------|------|
| One-dimensional layout | Flexbox |
| Two-dimensional layout | Grid |
| Simple alignment | Flexbox |
| Complex page layout | Grid |

In practice, **Flex and Grid are often used together**.

---

## Summary

Modern CSS layout mainly relies on two systems:

- **Flexbox** for linear layouts
- **CSS Grid** for two-dimensional layouts

Understanding these two tools makes front-end layout significantly easier and more powerful.