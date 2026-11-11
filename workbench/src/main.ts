import { createApp } from 'vue';
import { ixPlugin } from '@siemens/ix-vue';
import '@siemens/ix/dist/siemens-ix/siemens-ix.css';
import './styles.css';
import App from './App.vue';

const app = createApp(App);
app.use(ixPlugin);
app.mount('#app');
