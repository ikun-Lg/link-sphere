import axios from 'axios'
// import router from '../router'
import { ElMessage } from 'element-plus'

import {getAuthentication} from "@/utils/storage.js";


export const CONTENT_TYPE = {
    formData: 'application/x-www-form-urlencoded',
    jsonData: 'application/json'
}

export const baseUrl = "https://socialite.ljq1024.cc/api/v1"

const errorResult = {
    code: 'A0001',
    msg: '请求错误',
    data: null
}

/**
 * 1.创建 axios
 */
export const request = axios.create({
    // api的 base_url
    baseURL: baseUrl, //import.meta.env.BASE_URL,
    // 发生 cookies 当是跨域请求时 cross-domain requests
    withCredentials: true,
    // 请求超时时间
    timeout: 60000
})

/**
 * 2.request 请求拦截器
 */
request.interceptors.request.use(
    // 配置请求参数
    (config) => {
        // 携带本地会话 jwt token 值
        const token = getAuthentication()
        if (!token) {
            // router.push('/login')
            alert("JwtToken 为空！")
            return;
        }
        if (config.url !== '/login' && token) {
            config.headers['Authorization'] = token
        }
        // POST表单提交处理
        if (config.method === 'post' && config.headers['Content-Type'] === CONTENT_TYPE.formData) {
            let formdata = new FormData()
            Object.keys(config.data).forEach((key) => {
                formdata.append(key, config.data[key])
            })
            config.data = formdata
        }
        // GET提交对参数进行编码
        if (config.method === 'get' && config.params) {
            let url = config.url + '?'
            Object.keys(config.params).forEach((key) => {
                if (config.params[key] !== void 0 && config.params[key] !== null) {
                    url += `${key}=${encodeURIComponent(config.params[key])}&`
                }
            })
            url = url.substring(0, url.length - 1)
            config.params = {}
            config.url = url
        }
        return config
    },
    // 请求失败
    (error) => Promise.reject(error).catch((error) => console.log(error))
)

/**
 * 3.response 响应拦截器
 */
request.interceptors.response.use(
    // 正常返回
    (response) => {
        const result = response.data
        // 后端返回的状态码为 '00000' 表示处理成功
        if (result.code === 'SUCCESS_0000' /*import.meta.env.VITE_RESPONSE_SUCCESS*/) {
            ElMessage({
                type: 'success',
                message: result.message || '操作成功'
            })
            return Promise.resolve(result)
        }
        ElMessage({
            type: 'error',
            message: result.message || '操作失败'
        })

        // 失败时回调
        return Promise.reject(result).catch((error) => console.log(error))
    },
    // 客户端或者网络错误
    (fault) => Promise.reject(errorResult).catch((error) => console.log(error))
)

export default request
