import DefaultTheme from 'vitepress/theme'
import Layout from './Layout.vue'
import DemoVideo from './components/DemoVideo.vue'
import Screenshot from './components/Screenshot.vue'
import ScreenshotGrid from './components/ScreenshotGrid.vue'

export default {
  extends: DefaultTheme,
  Layout,
  enhanceApp({ app }) {
    app.component('DemoVideo', DemoVideo)
    app.component('Screenshot', Screenshot)
    app.component('ScreenshotGrid', ScreenshotGrid)
  },
}
