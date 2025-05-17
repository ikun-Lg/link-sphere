<template>
  <div class="message-container">
    <div
        v-for="message in messages"
        :key="message.id"
        class="message"
        :class="message.isSent ? 'sent' : 'received'"
    >
      <div class="message-header">
        {{ message.isSent ? '我' : `用户 ${message.senderId}` }}
      </div>
      <div class="message-content">{{ message.content }}</div>
      <div class="message-time">
        {{ formatTime(message.createdAt) }}
      </div>
    </div>
  </div>
</template>

<script setup>
import { defineProps } from 'vue'

const props = defineProps({
  messages: {
    type: Array,
    required: true
  },
  currentUserId: {
    type: String,
    default: ''
  }
})

const formatTime = (isoString) => {
  const date = new Date(isoString)
  return date.toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit'
  })
}
</script>

<style scoped>
.message-container {
  height: 500px;
  border: 1px solid #ddd;
  padding: 15px;
  margin-bottom: 20px;
  overflow-y: auto;
  border-radius: 8px;
  display: flex;
  flex-direction: column-reverse;
}

.message {
  margin: 10px 0;
  padding: 15px;
  border-radius: 15px;
  max-width: 70%;
  word-break: break-word;
}

.received {
  background: #e9ecef;
  align-self: flex-start;
}

.sent {
  background: #007bff;
  color: white;
  align-self: flex-end;
}

.message-header {
  font-weight: bold;
  margin-bottom: 5px;
}

.message-time {
  font-size: 0.8em;
  margin-top: 8px;
  opacity: 0.8;
}
</style>
