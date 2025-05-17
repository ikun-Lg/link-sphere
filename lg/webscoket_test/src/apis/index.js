
import { request } from '@/utils/request'

/**
 * 发送验证码接口
 */
export const getHistoryMessages = () => {
    return request({
        url: `/user/messages/unread`,
        method: 'get'
    })
}

//
export const markHistoryMessagesAsRead = () => {
    return request({
        url: `/user/messages/markRead`,
        method: 'GET'
    })
}
