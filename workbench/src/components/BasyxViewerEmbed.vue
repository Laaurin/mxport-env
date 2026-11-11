<script setup lang="ts">
defineProps<{
  url: string;
  viewerHost: string;
}>();
</script>

<template>
  <div class="basyx-embed-container">
    <iframe
      :key="url"
      :src="url"
      class="basyx-iframe"
      :title="`Official Eclipse BaSyx AAS Web UI (${viewerHost})`"
    ></iframe>
  </div>
</template>

<style scoped>
.basyx-embed-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 500px;
  border: 1px solid #1e293b;
  border-radius: 8px;
  overflow: hidden;
  background: #090d16;
}

.basyx-iframe {
  width: 100%;
  flex: 1;
  border: none;
  background: #ffffff;
}
</style>

