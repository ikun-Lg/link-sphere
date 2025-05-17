<template>
  <div class="container">
    <div class="login-box">
      <input
          v-model="currentUserId"
          type="text"
          placeholder="输入你的用户ID"
          :disabled="isConnected"
      />
      <button @click="handleConnect" :disabled="isConnected">连接</button>
      <button @click="disconnect" class="disconnect-btn" :disabled="!isConnected">
        断开
      </button>
      <div class="status">{{ connectionStatus }}</div>
    </div>

    <MessageList :messages="messages" :current-user-id="currentUserId" />

    <div class="input-box">
      <input
          v-model="messageInput"
          type="text"
          placeholder="输入消息..."
          @keyup.enter="sendChatMessage"
      />
      <input
          v-model="receiverId"
          type="text"
          placeholder="接收者ID"
          style="width: 120px"
      />
      <button @click="sendChatMessage" :disabled="!isConnected">发送</button>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onBeforeUnmount } from 'vue'
import SockJS from "sockjs-client";
import {Stomp} from "@stomp/stompjs";
import MessageList from './components/MessageList.vue'
import {getHistoryMessages, markHistoryMessagesAsRead} from "@/apis/index.js";
import {setAuthentication} from "@/utils/storage.js";

import { baseUrl } from './utils/request.js'

// 响应式状态
const currentUserId = ref()
const receiverId = ref('')
const messageInput = ref('')
const connectionStatus = ref('未连接')
const isConnected = ref(false)
const messages = reactive([])

// STOMP客户端实例
let stompClient = null

const authToken = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwiY29udGFjdEluZm9ybWF0aW9uIjoiMTg3MjI4NjQ1NTIiLCJleHAiOjE3NDc0OTM2OTQsInVzZXJJZCI6MSwiaWF0IjoxNzQ3NDA3Mjk0LCJqdGkiOiJhMWNhYmU1MS1kOGRlLTQ4NmUtODI3YS05NmM0MTc1MTBhNzQifQ.QdV_vV4w86Tde29YF8JfnFJzNCNl5WH0D-_rnY0eOWQ'

let headers = {
  Authorization: `Bearer ${authToken}`
};

// 处理连接
const handleConnect = async () => {

  console.log("请输入用户ID - currentUserId: ", currentUserId.value);
  if (!currentUserId.value) {
    alert('请输入用户ID')
    return
  }
  try {
    connectionStatus.value = '连接中...' + baseUrl;
    // const socket = new SockJS(`http://localhost:8089/api/v1/ws`)
    const socket = new SockJS(baseUrl + `/ws`)

    // 获取STOMP子协议的客户端对象
    stompClient = Stomp.over(socket);

    stompClient.connect(headers, () => {
      console.log(`用户ID: ${currentUserId.value} 正在连接`)
    })

    stompClient.onConnect = async () => {
      connectionStatus.value = `已连接（用户ID: ${currentUserId.value}）`
      isConnected.value = true

      // 订阅个人消息队列，并添加Token
      stompClient.subscribe(`/user/${currentUserId.value}/queue/messages`, (message) => {
        console.log("接受消息：", message);
        const msg = JSON.parse(message.body);
        addMessage(msg, false);
      }, headers);
      // 加载历史消息
      // fetchHistoryMessages()

      // 订阅 ACK 专用队列
      stompClient.subscribe(`/user/${currentUserId.value}/queue/acks`, (ackFrame) => {
        try {
          const ackData = JSON.parse(ackFrame.body);
          console.log('收到ACK:', ackData);

          const messageId = ackData.messageId;

          if (ackData.status === 'FAILED') {
            showError(`消息发送失败 (ID: ${messageId}): ${ackData.error}`);
            return
          }

          if (ackData.status === 'REPEAT') {
            // 重复ACK 不做处理
            return;
          }

          // 成功ACK
          const pending = pendingMessages.get(messageId);
          if (pending) {
            // 清理定时器和队列
            clearTimeout(pending.timer);
            pendingMessages.delete(messageId);

            // 更新本地存储
            localStorage.setItem('pendingMessages', JSON.stringify([...pendingMessages]));
          }
        } catch (e) {
          console.error('ACK处理异常:', e);
        }
      }, headers);

      // 订阅在线状态频道
      stompClient.subscribe('/topic/online', (message) => {
        console.log('用户上线:', message.body);
        // addOnlineUser(message.body);
      }, headers);

      stompClient.subscribe('/topic/offline', (message) => {
        console.log('用户下线:', message.body);
        // removeOnlineUser(message.body);
      }, headers);

      // 接收当前在线列表
      stompClient.subscribe(`/user/${currentUserId.value}/queue/online-list`, (message) => {
        const onlineList = JSON.parse(message.body);
        console.log("在线列表：", onlineList)
        // updateOnlineUsers(onlineList);
      }, headers);

      stompClient.subscribe(`/user/${currentUserId.value}/queue/advertisement`, (message) => {
        const onlineList = JSON.parse(message.body);
        console.log("广告信息：", onlineList)
      }, headers)

      // 开启心跳检测
      startHeartbeat()
      // 获取历史消息
      await fetchHistoryMessages()
      // 标记信息已读
      await markHistoryMessagesAsRead()
    }

    stompClient.onStompError = frame => {
      console.error('连接错误:', frame.headers)
      console.error('连接错误:', frame)
      connectionStatus.value = '连接失败'
    }

    stompClient.activate()
  } catch (error) {
    console.error('连接异常:', error)
    connectionStatus.value = '连接异常'
  }

}


// ==================== 核心对象定义 ====================
// 待确认消息队列（消息ID为键）
const pendingMessages = new Map();

// 最大重试次数
const MAX_RETRIES = 3;

// 使用 localStorage 持久化待确认消息（防止页面刷新丢失）
function savePendingMessages() {
  const messages = Array.from(pendingMessages.values());
  localStorage.setItem('pendingMessages', JSON.stringify(messages));
}

// 显示错误提示
function showError(message) {
  console.error('Error:', message);
  // 实际项目中可替换为 UI 提示（如 Toast 或 Alert）
  alert(message);
}

function generateMessageId() {
  return 'msg_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

// ==================== 消息发送逻辑 ====================
/**
 * 发送聊天消息
 */
const sendChatMessage = () => {
  const messageId = generateMessageId();
  const message = {
    messageId: messageId,
    senderId: currentUserId.value, // 假设已实现获取当前用户ID
    receiverId: receiverId.value,
    content: messageInput.value,
    timestamp: Date.now()
  };

  // 加入待ACK确认队列
  addToPendingQueue(messageId, message);
  console.log("发送消息：", message);
  // 发送消息（携带自定义头部） - websockt
  stompClient.publish({
    destination: '/app/chat/ack',
    body: JSON.stringify(message),
    headers: {
      'Authorization': `Bearer ${authToken}`,
      'message-id': messageId, // STOMP头部携带消息ID
      'sender-id': message.senderId
    }
  })
}

// ==================== 待确认队列管理 ====================
// 定义重试处理器
const retryHandler = (messageId, message) => {
  const pending = pendingMessages.get(messageId);
  if (!pending) return;

  if (pending.retries < MAX_RETRIES) {
    pending.retries++;
    console.log(`重试消息 ${messageId} (第 ${pending.retries} 次)`);

    // 指数退避：3s → 6s → 12s
    const timeout = 3000 * Math.pow(2, pending.retries - 1);
    pending.timer = setTimeout(retryHandler, timeout);

    // 发送消息（携带自定义头部）
    stompClient.publish({
      destination: '/app/chat/ack',
      body: JSON.stringify(message),
      headers: {
        'Authorization': `Bearer ${authToken}`,
        'message-id': messageId, // STOMP头部携带消息ID
        'sender-id': message.senderId
      }
    })
  } else {
    // 超过最大重试次数
    pendingMessages.delete(messageId);
    showError(`消息发送失败：服务器无响应 (ID: ${messageId})`);
  }
};

/**
 * 添加消息到待确认队列
 */
function addToPendingQueue(messageId, message) {
  // 初始加入队列
  pendingMessages.set(messageId, {
    message: message,
    retries: 0,
    timer: setTimeout(retryHandler, 3000) // 初始超时3秒
  });

  // 持久化到 localStorage（防止页面刷新丢失）
  savePendingMessages()
}


// ==================== 初始化恢复未确认消息 ====================
// 页面加载时恢复未确认消息（网络断开后）
window.addEventListener('load', () => {
  const saved = JSON.parse(localStorage.getItem('pendingMessages') || []);
  saved.forEach(([messageId, pending]) => {
    pendingMessages.set(messageId, {
      ...pending,
      timer: setTimeout(() => retryHandler(messageId), pending.timeout)
    });
  });
});

// ==================== WebSocket连接配置 ====================
let heartbeatInterval = null;
const HEARTBEAT_INTERVAL = 25000; // 25秒发送一次心跳（建议小于服务端超时时间）
const RECONNECT_DELAY = 1000;     // 断开后1秒重连

// ==================== 工具函数 ====================
function getCurrentUserId() {
  // 实现获取当前用户ID的逻辑，例如从localStorage或状态管理
  return currentUserId.value;
}

// ==================== 心跳管理 ====================
function startHeartbeat() {
  heartbeatInterval = setInterval(() => {
    if (stompClient && stompClient.connected) {
      sendHeartbeat();
    } else {
      console.warn('心跳发送失败：连接已断开,重连......');
      onConnectError('心跳发送失败：连接已断开')
    }
  }, HEARTBEAT_INTERVAL); // 25秒发送一次（小于服务端检测间隔）
}

function stopHeartbeat() {
  if (heartbeatInterval) {
    clearInterval(heartbeatInterval);
    // 调用断开连接的方法
    disconnect();
  }
}

function sendHeartbeat() {
  try {
    // 发送心跳到服务端（不需要内容）（携带自定义头部）
    stompClient.publish({
      destination: '/app/heartbeat',
      body: {},
      headers: {
        'Authorization': `Bearer ${authToken}`,
      }
    })
    console.debug('心跳已发送');
  } catch (e) {
    console.error('心跳发送异常:', e);
    // 触发重连
    onConnectError(e);
  }
}

function onConnectError(error) {
  console.error('连接失败:', error);
  // 清理资源
  stopHeartbeat();
  // 延迟重连
  setTimeout(() => {
    console.log('尝试重新连接...');
    currentUserId.value = '1'
    handleConnect();
  }, RECONNECT_DELAY);
}

// 断开连接
const disconnect = (() => {
  console.log("调用关闭连接接口")
  if (stompClient) {
    stompClient.disconnect(
        () => {
          console.log("Disconnected");
        }, headers
    );
    stompClient = null
  }
  isConnected.value = false
  connectionStatus.value = '已断开连接'
  currentUserId.value = ''
})


// 添加消息到列表
const addMessage = (msg, isSent) => {
  messages.unshift({
    id: msg.id,
    senderId: msg.senderId,
    content: msg.content,
    sendTime: msg.sendTime,
    isSent: isSent
  })
}

// 获取历史消息
const fetchHistoryMessages = async () => {

  setAuthentication(authToken)

  try {
    const response = await getHistoryMessages()
    const data = response.data
    console.log("获取历史消息：",data)
    data.forEach(message => {
      message.messageList.forEach(item => {
        addMessage(item, item.senderId === currentUserId.value);
      })
    });
  } catch (error) {
    console.error('获取历史消息失败:', error);
  }
}

// 组件卸载前断开连接
onBeforeUnmount(() => {
  if (stompClient) disconnect()
})
</script>

<style scoped>
.container {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
}

.login-box {
  margin-bottom: 20px;
  padding: 15px;
  background: #f5f5f5;
  border-radius: 8px;
}

.input-box {
  display: flex;
  gap: 10px;
  margin-top: 20px;
}

input[type="text"] {
  flex: 1;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 4px;
}

button {
  padding: 10px 20px;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  transition: background 0.3s;
}

button:hover {
  background: #0056b3;
}

button:disabled {
  background: #6c757d;
  cursor: not-allowed;
}

.disconnect-btn {
  background: #dc3545;
}

.disconnect-btn:hover {
  background: #bb2d3b;
}

.status {
  color: #6c757d;
  font-size: 0.9em;
  margin-top: 10px;
}
</style>
