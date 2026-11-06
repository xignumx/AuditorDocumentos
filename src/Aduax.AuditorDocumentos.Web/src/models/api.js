/**
 * @template TItem
 * @typedef {Object} PaginatedRequest
 * @property {string} filter
 * @property {number} page
 * @property {number} size
 */

/**
 * @template TItem
 * @typedef {Object} PaginatedData
 * @property {TItem[]} data
 * @property {number} page
 * @property {number} size
 * @property {number} totalRecords
 * @property {number} totalPages
 * @property {boolean} more
 */

/**
 * @template TItem
 * @typedef {Object} ApiResponse
 * @property {boolean} success
 * @property {string} message
 * @property {PaginatedData<TItem>} data
 */

/**
 * @template TData
 * @typedef {Object} ApiResponseData
 * @property {boolean} success
 * @property {string} message
 * @property {TData} data
 */

/**
 * @typedef {Object} ApiResponseBase
 * @property {boolean} success
 * @property {string} message
 * @property {null} [data]
 */

/**
 * @template TData
 * @typedef {Object} MotorConfigRequestBase
 * @property {string} idCliente
 * @property {number} idTipoDocumentoVucem
 * @property {TData} [data]
 */

export {};
