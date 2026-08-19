/**
 * Small helper around the NUI callback endpoint.
 *
 * `GetParentResourceName` only exists inside the game's CEF frame, so the
 * helpers fall back to a no-op when the UI is opened in a normal browser during
 * development.
 */
const resourceName =
	typeof GetParentResourceName === 'function' ? GetParentResourceName() : null

export const inGame = resourceName !== null

/**
 * Posts a message back to the Lua side.
 * @param {string} endpoint the RegisterNUICallback name
 * @param {object} [data] JSON serialisable payload
 * @returns {Promise<any>} the callback's response, or null outside the game
 */
export async function post(endpoint, data = {}) {
	if (!inGame) {
		console.info(`[I-Voice] nui:${endpoint}`, data)
		return null
	}

	try {
		const response = await fetch(`https://${resourceName}/${endpoint}`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json; charset=UTF-8' },
			body: JSON.stringify(data),
		})
		return await response.json()
	} catch (err) {
		console.error(`[I-Voice] nui:${endpoint} failed`, err)
		return null
	}
}
