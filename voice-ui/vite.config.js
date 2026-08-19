import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

/**
 * The bundle is emitted as a classic IIFE so the NUI frame can load it with a
 * plain `<script>` tag; Vite still writes a module-style tag, so rewrite it.
 */
function classicScriptTag() {
	return {
		name: 'ivoice-classic-script-tag',
		enforce: 'post',
		transformIndexHtml(html) {
			return html.replace(/<script type="module" crossorigin/g, '<script defer')
		},
	}
}

// The built output is loaded straight off disk by the FiveM NUI frame, so paths
// have to stay relative and filenames stable — fxmanifest.lua lists them by
// name (`ui/js/*.js`, `ui/css/*.css`).
export default defineConfig({
	plugins: [vue(), classicScriptTag()],
	base: './',
	build: {
		outDir: '../ui',
		emptyOutDir: true,
		sourcemap: false,
		target: 'chrome108',
		cssCodeSplit: true,
		rollupOptions: {
			output: {
				format: 'iife',
				inlineDynamicImports: true,
				entryFileNames: 'js/app.js',
				chunkFileNames: 'js/[name].js',
				assetFileNames: (assetInfo) => {
					const name = assetInfo.names?.[0] ?? assetInfo.name ?? ''
					if (name.endsWith('.css')) return 'css/app.css'
					return 'assets/[name][extname]'
				},
			},
		},
	},
})
