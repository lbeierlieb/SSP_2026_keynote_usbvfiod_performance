<template>
  <div
    v-if="$nav.currentPage > 1 && $nav.currentPage < $nav.total"
    class="absolute bottom-3 right-5 text-sm opacity-60"
  >
    {{ $nav.currentPage }} / {{ $nav.total }}
  </div>
</template>
