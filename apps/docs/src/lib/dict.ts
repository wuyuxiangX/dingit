/**
 * Text dictionary for the marketing / landing surface.
 *
 * MDX content is translated by Fumadocs via `*.zh.mdx` convention. This file
 * only covers React components (Hero, Feature cards, Quick-link cards) where
 * the text lives in TSX and can't be fronted by MDX.
 *
 * Add a new locale by mirroring every key. TypeScript will catch any misses.
 */

import type { Locale } from './i18n';

type HomeDict = {
  badge: string;
  heroTitleLine1: string;
  heroTitleLine2: string;
  heroSubtitle: string;
  ctaPrimary: string;
  ctaSecondary: string;
  features: {
    interactive: { title: string; body: string };
    threeClients: { title: string; body: string };
    selfHosted: { title: string; body: string };
  };
  startHere: string;
  quickLinks: {
    quickstart: { title: string; body: string };
    cliReference: { title: string; body: string };
    selfHost: { title: string; body: string };
    apiReference: { title: string; body: string };
  };
};

export const home: Record<Locale, HomeDict> = {
  en: {
    badge: 'Dingit Docs · v1.2',
    heroTitleLine1: 'Self-hosted interactive',
    heroTitleLine2: 'notifications, everywhere.',
    heroSubtitle:
      'Dingit turns scripts, servers, and CI jobs into first-class notifications — with interactive actions and a callback hook, delivered to App, CLI, and Server in real time.',
    ctaPrimary: 'Get Started',
    ctaSecondary: 'View on GitHub',
    features: {
      interactive: {
        title: 'Interactive',
        body: 'Not just a push — every notification carries Actions and a server-side callback hook. Click once in the App, your script hears back.',
      },
      threeClients: {
        title: 'Three clients, one notification',
        body: 'Server + Flutter App + Go CLI. Send from any side, receive on every side, state stays in sync over WebSocket.',
      },
      selfHosted: {
        title: 'Self-hosted, yours',
        body: 'Your PostgreSQL, your server, your data. Zero third-party lock-in. One docker-compose up away from production.',
      },
    },
    startHere: 'Start here',
    quickLinks: {
      quickstart: {
        title: '5-minute quickstart',
        body: 'curl → App bell → callback — end to end in 5 minutes.',
      },
      cliReference: {
        title: 'CLI reference',
        body: 'Every dingit subcommand, every flag, with copy-paste examples.',
      },
      selfHost: {
        title: 'Self-host guide',
        body: 'Deploy the server with docker-compose, systemd, or cloud targets.',
      },
      apiReference: {
        title: 'API reference',
        body: 'OpenAPI-driven, interactive. Try endpoints without leaving the page.',
      },
    },
  },
  zh: {
    badge: 'Dingit 文档 · v1.2',
    heroTitleLine1: '自托管的可交互通知',
    heroTitleLine2: '一次送达所有设备。',
    heroSubtitle:
      'Dingit 把脚本、服务器和 CI 任务变成一等公民的通知 —— 带可点击的 Action 和 callback 回调钩子，实时送达 App、CLI 和 Server 三端。',
    ctaPrimary: '快速上手',
    ctaSecondary: '在 GitHub 查看',
    features: {
      interactive: {
        title: '可交互',
        body: '不只是推送 —— 每条通知都带 Action 按钮和服务端 callback 钩子。App 上一次点击，脚本立刻收到回调。',
      },
      threeClients: {
        title: '三端同一张卡片',
        body: 'Server + Flutter App + Go CLI。任意一端发送，所有端接收，状态通过 WebSocket 实时同步。',
      },
      selfHosted: {
        title: '完全自托管',
        body: '你的 PostgreSQL、你的服务器、你的数据。零第三方锁定，一行 docker-compose up 即可上线。',
      },
    },
    startHere: '从这里开始',
    quickLinks: {
      quickstart: {
        title: '5 分钟快速上手',
        body: 'curl → App 响铃 → callback 回调，端到端一次跑通。',
      },
      cliReference: {
        title: 'CLI 参考',
        body: '每个 dingit 子命令、每个 flag，附完整可复制示例。',
      },
      selfHost: {
        title: '自托管指南',
        body: '用 docker-compose、systemd 或云平台部署服务端。',
      },
      apiReference: {
        title: 'API 参考',
        body: 'OpenAPI 驱动的交互式文档，不用离开页面就能 Try it out。',
      },
    },
  },
};
