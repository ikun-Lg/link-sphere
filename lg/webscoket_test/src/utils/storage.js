export const AUTHENTICATION_KEY = 'authentication'
export const USERNAME_KEY = 'username'
export const DATASOURCE_KEY = 'datasource'
export const DATABASE_KEY = 'database'
export const TABLE_KEY = 'table'

/************************************************************** */
/**
 * 存储 JwtToken
 * @param {String} authentication JwtToken
 */
export function setAuthentication(authentication) {
  sessionStorage.setItem(AUTHENTICATION_KEY, authentication)
}
/**
 * 获取 JwtToken
 * @returns JwtToken
 */
export function getAuthentication() {
  return sessionStorage.getItem(AUTHENTICATION_KEY)
}

/************************************************************** */

/**
 * 存储 username
 * @param {String} authentication JwtToken
 */
export function setUsername(username) {
  sessionStorage.setItem(USERNAME_KEY, username)
}
/**
 * 获取 username
 * @returns 用户名
 */
export function getUsername() {
  return sessionStorage.getItem(USERNAME_KEY)
}

/************************************************************** */

/**
 * 存储 datasource
 * @param {Object} datasource 数据源
 */
export function setDatasource(datasource) {
  sessionStorage.setItem(DATASOURCE_KEY, JSON.stringify(datasource))
}
/**
 * 获取 datasource
 * @returns 数据源
 */
export function getDatasource() {
  if (sessionStorage.getItem(DATASOURCE_KEY)) {
    return JSON.parse(sessionStorage.getItem(DATASOURCE_KEY))
  }
  return {}
}

/************************************************************** */

/**
 * 存储数据库名
 * @param {String} dbname 数据库名
 */
export function setDatabase(dbname) {
  sessionStorage.setItem(DATABASE_KEY, dbname)
}
/**
 * 获取数据库名
 * @returns 数据库名
 */
export function getDatabase() {
  return sessionStorage.getItem(DATABASE_KEY)
}

/************************************************************** */

/**
 * 存储表名
 * @param {String} tname 表名
 */
export function setTable(tname) {
  sessionStorage.setItem(TABLE_KEY, tname)
}
/**
 * 获取表名
 * @returns 表名
 */
export function getTable() {
  return sessionStorage.getItem(TABLE_KEY)
}
