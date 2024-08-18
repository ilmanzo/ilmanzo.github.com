---
layout: post
description: "Checking out the functional features of Crystal standard library"
title: "Exploring functional features of Crystal"
categories: programming
tags: [tutorial, crystal, functional, 'crystal lang', 'standard library']
author: Andrea Manzini
date: 2024-08-19
draft: true
---

## Intro

As a Crystal Language fan, every now and then I like to delve deeper in some details; on this blog post I want to shed some light into the functional aspects of the Crystal standard library. 

## The basics

- `.size` gives the number of elements in the collection; easy!

- `.count` gives the number of elements in the collections for those the function passed is `true`:

    ```crystal
    a=[1, 2, 3, 4, 5, 6, 7]
    p a.count &.odd? 
    4
    ```
    because there are 4 odd numbers: 1,3,5,7


- `.min` , `.max`, `.minmax` returns respectively the minimum value / the maximum value of the collection and a handy tuple with both values

- `.empty?` , `.present?` : the first returns `true` if the collection does not contain elements; the second returns `true` when the collection contains elements

- `.all?`, `.any?`, `.one?`, `.none?`: these methods returns `true` if the block passed is `true` for the corresponding situation:
    ```crystal
    a=[1, 2, 3, 4, 5, 6, 7]
    p a.all? {|x| x>6}
    false
    p a.any? {|x| x>6}
    true
    p a.one? {|x| x>6}
    true
    p a.none? {|x| x>6}
    false
    ```



## Searching and selecting

## Grouping

## Operations

