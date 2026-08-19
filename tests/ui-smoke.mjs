/**
 * Smoke test for the built NUI page.
 *
 * Loads `ui/index.html` in headless Chromium, replays the messages the Lua side
 * sends and asserts the overlay and settings panel render what they should.
 * Run with `node tests/ui-smoke.mjs` after `npm run build` in `voice-ui/`.
 */
import { chromium } from 'playwright'
import { existsSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const page_url = pathToFileURL(resolve(here, '..', 'ui', 'index.html')).href

let failures = 0

function check(name, condition, detail = '') {
	if (condition) {
		console.log(`  ok   ${name}`)
	} else {
		failures += 1
		console.log(`  FAIL ${name}${detail ? ` — ${detail}` : ''}`)
	}
}

/**
 * Prefer an explicitly configured browser, then the one this sandbox ships, and
 * otherwise let Playwright resolve its own download.
 */
function resolveExecutablePath() {
	const configured = process.env.CHROMIUM_PATH
	if (configured) return configured
	if (existsSync('/opt/pw-browsers/chromium')) return '/opt/pw-browsers/chromium'
	return undefined
}

const browser = await chromium.launch({ executablePath: resolveExecutablePath() })
const page = await browser.newPage()

const consoleErrors = []
page.on('pageerror', (err) => consoleErrors.push(String(err)))
page.on('console', (msg) => {
	if (msg.type() === 'error') consoleErrors.push(msg.text())
})

await page.goto(page_url)
await page.waitForSelector('#app', { state: 'attached' })

/**
 * Replays one sendUIMessage payload and waits long enough for Vue to patch the
 * DOM and any leave transition (140ms) to finish.
 */
async function send(payload) {
	await page.evaluate((data) => window.postMessage(data, '*'), payload)
	await page.waitForTimeout(220)
}

console.log('mounting')
check('app mounted without errors', consoleErrors.length === 0, consoleErrors.join('; '))

console.log('proximity overlay')
await send({
	uiEnabled: true,
	uiScale: 100,
	uiPosition: 'bottom-right',
	voiceModes: JSON.stringify([
		[3.0, 'Whisper'],
		[7.0, 'Normal'],
		[15.0, 'Shouting'],
	]),
	voiceMode: 1,
})
check('range row shows the mode', (await page.textContent('.row.range')).includes('Normal'))
check('two range bars lit', (await page.locator('.meter i.lit').count()) === 2)

console.log('radio')
await send({ radioChannel: 1425, radioChannels: [1425, 900], radioEnabled: true })
check('radio row formats the channel', (await page.textContent('.row.radio')).includes('142.5 MHz'))
check('monitored channel count badge', (await page.textContent('.row.radio')).includes('+1'))

await send({ usingRadio: true })
check('radio row goes active', await page.locator('.row.radio.active').isVisible())

console.log('talker list')
await send({
	showTalkerList: true,
	radioTalkers: [{ id: 7, name: 'Dispatch', channel: 1425 }],
})
check('talker rendered', (await page.textContent('.talkers')).includes('Dispatch'))

await send({ showTalkerList: false })
check('talker list hides when disabled', (await page.locator('.talkers').count()) === 0)

console.log('call + megaphone')
await send({ callInfo: 42, usingMegaphone: true })
check('call row visible', await page.locator('.row.call').isVisible())
check('megaphone row visible', await page.locator('.row.megaphone').isVisible())

console.log('empty lua tables')
// Lua serialises an empty table as {} rather than [], which must not crash.
await send({ radioChannels: {}, radioTalkers: {}, blocked: {} })
check('empty tables tolerated', (await page.locator('.row.range').count()) === 1)

console.log('notification')
await send({ notification: { kind: 'error', text: 'Channel 500 is full.' } })
check('notification shown', (await page.textContent('.notification')).includes('full'))

console.log('settings panel')
await send({
	settingsOpen: true,
	radioChannels: [1425, 900],
	volumes: { radio: 30, phone: 60, megaphone: 80 },
	micClicks: true,
	blocked: [12, 34],
	megaphoneEnabled: true,
})
check('panel opens', await page.locator('.panel').isVisible())
// radio, phone, megaphone and the overlay scale slider
check('four sliders', (await page.locator('.slider-row input[type=range]').count()) === 4)
check('blocked players listed', (await page.textContent('.panel')).includes('Player 12'))
check('channel list rendered', (await page.textContent('.panel')).includes('90.0 MHz'))

// Toggling a switch should not throw even though there's no Lua side to answer.
await page.locator('.switch input').first().click()
await page.waitForTimeout(120)

await send({ settingsOpen: false })
check('panel closes', (await page.locator('.panel').count()) === 0)

console.log('overlay disabled')
await send({ uiEnabled: false })
check('overlay hidden', (await page.locator('.overlay').count()) === 0)

check('no runtime errors overall', consoleErrors.length === 0, consoleErrors.join('; '))

await browser.close()

console.log(failures === 0 ? '\nAll UI smoke checks passed.' : `\n${failures} check(s) failed.`)
process.exit(failures === 0 ? 0 : 1)
