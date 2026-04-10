/**
 * Text dictionary for the marketing / landing surface.
 *
 * The shape is an *editorial* one: the docs home reads like a small
 * zine about interactive notifications, so the keys mirror magazine
 * furniture — section markers, pull quotes, dispatches, colophon —
 * rather than generic landing-page slots.
 *
 * Rules:
 *   1. Every English key has a Chinese mirror. TypeScript catches gaps.
 *   2. Locale-agnostic content (shell commands, docker-compose snippets)
 *      does NOT live here — it's hard-coded in the page component.
 *   3. Chinese is not a literal translation. It's rewritten to feel
 *      natural in Chinese and keep the same editorial tone.
 */

import type { Locale } from './i18n';

type EssayColumn = { number: string; title: string; body: string };
type AnatomyStep = { n: string; title: string; body: string };
type Dispatch = { source: string; quote: string; filedBy: string };
type LinkCard = { title: string; body: string };

type HomeDict = {
  hero: {
    eyebrow: string;
    titleLine1: string;
    titleLine2: string;
    subtitle: string;
    ctaPrimary: string;
    ctaSecondary: string;
  };

  essay: {
    sectionMarker: string;
    label: string;
    pullQuote: string;
    pullQuoteAttribution: string;
    interactive: EssayColumn;
    threeClients: EssayColumn;
    selfHosted: EssayColumn;
  };

  anatomy: {
    sectionMarker: string;
    label: string;
    title: string;
    intro: string;
    step1: AnatomyStep;
    step2: AnatomyStep;
    step3: AnatomyStep;
    step4: AnatomyStep;
    footnote: string;
  };

  install: {
    sectionMarker: string;
    label: string;
    title: string;
    body: string;
    curlLabel: string;
    curlSubtitle: string;
    dockerLabel: string;
    dockerSubtitle: string;
    binaryLabel: string;
    binarySubtitle: string;
    postamble: string;
  };

  dispatches: {
    sectionMarker: string;
    label: string;
    title: string;
    intro: string;
    ci: Dispatch;
    training: Dispatch;
    homeLab: Dispatch;
    cron: Dispatch;
  };

  selfHost: {
    sectionMarker: string;
    label: string;
    title: string;
    body: string;
    byline: string;
    ctaLabel: string;
  };

  openSource: {
    sectionMarker: string;
    label: string;
    title: string;
    body: string;
    licenseLabel: string;
    licenseValue: string;
    sourceLabel: string;
    sourceValue: string;
    roadmapLabel: string;
    roadmapValue: string;
    authorLabel: string;
    authorValue: string;
  };

  quickLinks: {
    sectionMarker: string;
    label: string;
    title: string;
    quickstart: LinkCard;
    cliReference: LinkCard;
    selfHost: LinkCard;
    apiReference: LinkCard;
  };

  colophon: {
    title: string;
    setInLine: string;
    builtWithLine: string;
    hostingLine: string;
    licenseLine: string;
    signature: string;
    docsLabel: string;
    githubLabel: string;
    changelogLabel: string;
    roadmapLabel: string;
  };
};

export const home: Record<Locale, HomeDict> = {
  en: {
    hero: {
      eyebrow: 'Issue 01 · Spring 2026 · A field guide',
      titleLine1: 'Self-hosted interactive',
      titleLine2: 'notifications, everywhere.',
      subtitle:
        'Dingit is a small piece of software that turns your scripts, servers, and CI jobs into first-class notifications — with actions you can tap and a callback hook that calls your code back.',
      ctaPrimary: 'Read the docs',
      ctaSecondary: 'Source on GitHub',
    },

    essay: {
      sectionMarker: '§ 01',
      label: 'First Principles',
      pullQuote: '“The best notification is the one that calls you back.”',
      pullQuoteAttribution: '— The Dingit thesis, abridged',
      interactive: {
        number: 'I.',
        title: 'Interactive, not ambient.',
        body: 'A push that only tells you something happened is half a feature. Every Dingit notification carries Actions and a server-side callback hook — one tap on the App bell, and your script hears back, on the same side you fired from.',
      },
      threeClients: {
        number: 'II.',
        title: 'Three clients, one card.',
        body: 'Server, Flutter App, and Go CLI are equal citizens. Send from any side, receive on every side; state stays in sync over WebSocket. The card you actioned on your phone is the card your terminal already knows about.',
      },
      selfHosted: {
        number: 'III.',
        title: 'Yours, front to back.',
        body: 'Your PostgreSQL. Your server. Your data. No vendor on the path between your script and your phone. One `docker-compose up` away from production — and nothing to un-install when you change your mind.',
      },
    },

    anatomy: {
      sectionMarker: '§ 02',
      label: 'Field Notes',
      title: 'The anatomy of a ding.',
      intro:
        'Four moving parts. Each one does one thing. Follow a notification from the script that fires it to the callback that closes the loop.',
      step1: {
        n: '01',
        title: 'The script fires.',
        body: 'A `curl` against `/api/notifications` with a title, a body, and a list of Actions. The server persists to PostgreSQL¹ and returns an id before the request even finishes.',
      },
      step2: {
        n: '02',
        title: 'The server broadcasts.',
        body: 'Every connected client — phone, desktop, CLI — gets the new card pushed over WebSocket. No polling, no delay, no "pull to refresh." If a client was offline, it picks up the backlog on reconnect.',
      },
      step3: {
        n: '03',
        title: 'The human acts.',
        body: 'The App buzzes once. You glance at the card, tap an Action (or swipe to dismiss). The App PATCHes status back to the server; the server broadcasts the new state to every other client.',
      },
      step4: {
        n: '04',
        title: 'The callback fires.',
        body: 'If you wired a `callback_url`, the server POSTs a signed payload back — `{ notification_id, action_id, signature }`. Your CI reruns, your deploy rolls back, your training job resumes. The loop closes.',
      },
      footnote:
        '¹ Schema is versioned via goose; migrations live in apps/server/internal/db/migrations and are applied at boot.',
    },

    install: {
      sectionMarker: '§ 03',
      label: 'Quickstart',
      title: 'Sixty seconds to your first ding.',
      body:
        'Three ways to get the server running. Pick whichever matches the kind of host you already trust. None of them ask you to hand over a database.',
      curlLabel: 'curl — one-liner',
      curlSubtitle: 'For a VM or a fresh laptop',
      dockerLabel: 'docker — compose',
      dockerSubtitle: 'The happy path',
      binaryLabel: 'binary — release',
      binarySubtitle: 'For air-gapped hosts',
      postamble:
        'Then point the App at your server and fire the first one: `dingit send "hello world"`.',
    },

    dispatches: {
      sectionMarker: '§ 04',
      label: 'Field Dispatches',
      title: 'Notes from the wire.',
      intro:
        'Four small stories from Dingit in the wild. None of them need a retention dashboard; each one started with a single `curl`.',
      ci: {
        source: '@ci-pipeline',
        quote:
          '“Build failed at 3am. Phone buzzed once. Tapped Rerun, back to sleep in thirty seconds. No GitHub app, no Slack bot, no webhook relay service.”',
        filedBy: 'Filed by — a night-shift solo developer',
      },
      training: {
        source: '@training-loop',
        quote:
          '“Forty-eight hour GPU run. One ping when the loss plateaued, one when the checkpoint saved. No more refreshing tmux every hour.”',
        filedBy: 'Filed by — a lab owner with one 4090',
      },
      homeLab: {
        source: '@home-assistant',
        quote:
          '“Doorbell, porch camera, and the 3D-printer finishing all hit the same card stack. The kids can tap Dismiss. I can tap Open in Grafana.”',
        filedBy: 'Filed by — a parent with too many Raspberry Pis',
      },
      cron: {
        source: '@cron-daily',
        quote:
          '“Silent backup failures, turned into actionable cards with a Retry button. Takes ten extra lines in the backup script.”',
        filedBy: 'Filed by — a sysadmin who stopped writing postmortems',
      },
    },

    selfHost: {
      sectionMarker: '§ 05',
      label: 'Bring Your Own Server',
      title: 'Your data, your host, your rules.',
      body:
        'The entire server is one Go binary and a PostgreSQL database. No telemetry, no license server, no phoning home. Paste the compose file, set an API key, done.',
      byline: 'Two files. Four minutes.',
      ctaLabel: 'Read the self-host guide →',
    },

    openSource: {
      sectionMarker: '§ 06',
      label: 'Built in Public',
      title: 'Every line of it, readable.',
      body:
        'Dingit is a one-person side project released under a permissive license. The server, the App, the CLI, even this website — same repo, same commit history, same issue tracker.',
      licenseLabel: 'License',
      licenseValue: 'MIT',
      sourceLabel: 'Source',
      sourceValue: 'github.com/wuyuxiangX/dingit',
      roadmapLabel: 'Roadmap',
      roadmapValue: 'Linear (public)',
      authorLabel: 'Author',
      authorValue: '@wuyuxiangX',
    },

    quickLinks: {
      sectionMarker: '§ 07',
      label: 'Start Here',
      title: 'Four ways in.',
      quickstart: {
        title: '5-minute quickstart',
        body: 'curl → App bell → callback — end to end.',
      },
      cliReference: {
        title: 'CLI reference',
        body: 'Every subcommand, every flag, with copy-paste examples.',
      },
      selfHost: {
        title: 'Self-host guide',
        body: 'docker-compose, systemd, cloud — pick one.',
      },
      apiReference: {
        title: 'API reference',
        body: 'OpenAPI-driven. Try endpoints without leaving the page.',
      },
    },

    colophon: {
      title: 'Colophon',
      setInLine:
        'Set in DM Serif Display for headlines and Plus Jakarta Sans for the body.',
      builtWithLine:
        'Built with Next.js 16, Fumadocs 16, Tailwind CSS v4, TypeScript.',
      hostingLine:
        'Served from one small self-hosted container; no CDN tracking, no analytics cookies, no third-party fonts.',
      licenseLine:
        'Dingit is released under the MIT license. The source for this page is in the same repository as the product.',
      signature:
        'A one-person side project by @wuyuxiangX. Filed from Hangzhou, 杭州.',
      docsLabel: 'Documentation',
      githubLabel: 'GitHub',
      changelogLabel: 'Changelog',
      roadmapLabel: 'Roadmap',
    },
  },

  zh: {
    hero: {
      eyebrow: '第 01 期 · 2026 春 · 一本小册子',
      titleLine1: '自托管的可交互通知',
      titleLine2: '一次送达所有设备。',
      subtitle:
        'Dingit 是一个小小的软件，它把你的脚本、服务器和 CI 任务变成一等公民的通知 —— 带可点击的 Action 按钮和 callback 回调钩子，让代码接收到来自人手的回应。',
      ctaPrimary: '开始阅读',
      ctaSecondary: '在 GitHub 查看源码',
    },

    essay: {
      sectionMarker: '§ 01',
      label: '第一性原理',
      pullQuote: '「最好的通知，是那种会回头找你的通知。」',
      pullQuoteAttribution: '— Dingit 宣言，节选',
      interactive: {
        number: '其一',
        title: '可交互，而非环境音。',
        body: '只告诉你"发生了什么"的推送，只做了一半的事情。每条 Dingit 通知都自带 Action 按钮和服务端 callback 回调 —— App 上一次点击，你的脚本立刻收到回应，从同一侧触发、同一侧接收。',
      },
      threeClients: {
        number: '其二',
        title: '三端，一张卡。',
        body: 'Server、Flutter App、Go CLI 是同一等公民。任意一端发送，所有端接收；状态通过 WebSocket 实时同步。你在手机上点过的卡片，终端里立刻就知道。',
      },
      selfHosted: {
        number: '其三',
        title: '从头到尾都是你的。',
        body: '你的 PostgreSQL、你的服务器、你的数据。脚本到手机之间不经过任何第三方。一行 `docker-compose up` 即可上线 —— 哪天想撤掉，没人需要被通知。',
      },
    },

    anatomy: {
      sectionMarker: '§ 02',
      label: '现场笔记',
      title: '一声 Ding 的构造。',
      intro:
        '四个零件，每个只做一件事。跟着一条通知从脚本的那一行，走到 callback 回调的那一行，看完整条回路。',
      step1: {
        n: '01',
        title: '脚本触发',
        body: '一个 `curl` 打到 `/api/notifications`，带 title、body 和 Action 列表。服务端持久化到 PostgreSQL¹ 后立刻返回 id，请求几乎无感。',
      },
      step2: {
        n: '02',
        title: '服务端广播',
        body: '所有已连接的客户端 —— 手机、桌面、CLI —— 通过 WebSocket 收到新卡片。不是轮询，不是延迟送达，没有"下拉刷新"。离线的客户端重连后会自动补齐。',
      },
      step3: {
        n: '03',
        title: '人类响应',
        body: 'App 响铃一次。你扫一眼卡片、点 Action（或者滑掉 Dismiss）。App PATCH 把状态同步回服务端；服务端再把新状态广播给其他所有客户端。',
      },
      step4: {
        n: '04',
        title: 'Callback 回调',
        body: '如果你配了 `callback_url`，服务端会 POST 一段签名过的 payload 过去 —— `{ notification_id, action_id, signature }`。你的 CI 重跑、部署回滚、训练任务继续，完整的回路就此闭合。',
      },
      footnote:
        '¹ Schema 通过 goose 做版本化迁移；迁移文件在 apps/server/internal/db/migrations，启动时自动应用。',
    },

    install: {
      sectionMarker: '§ 03',
      label: '快速上手',
      title: '六十秒内响起第一声。',
      body:
        '三种起服务的方式，挑一个和你习惯的主机最接近的。没有一种会让你把数据库交给别人。',
      curlLabel: 'curl · 一行命令',
      curlSubtitle: 'VM 或新装的笔记本',
      dockerLabel: 'docker · compose',
      dockerSubtitle: '最省事的路径',
      binaryLabel: '二进制 · release',
      binarySubtitle: '断网环境适用',
      postamble:
        '然后把 App 指向你的服务器，发出第一声：`dingit send "hello world"`。',
    },

    dispatches: {
      sectionMarker: '§ 04',
      label: '田野来信',
      title: '来自现场的四则短讯。',
      intro:
        '四个真实场景，没有一个需要留存仪表盘或运营团队。每一个都从一条 `curl` 开始。',
      ci: {
        source: '@ci-pipeline',
        quote:
          '「凌晨三点 build 挂了。手机震一下，点 Rerun，三十秒后继续睡。没装 GitHub App、没 Slack bot、没 webhook 中继。」',
        filedBy: '来信人 · 一个夜班 solo 开发者',
      },
      training: {
        source: '@training-loop',
        quote:
          '「四十八小时 GPU 训练。loss 平稳时响一次，checkpoint 保存时再响一次。不用每小时刷 tmux 了。」',
        filedBy: '来信人 · 一台 4090 的实验室主人',
      },
      homeLab: {
        source: '@home-assistant',
        quote:
          '「门铃、门廊摄像头、3D 打印机完工，全部打到同一个卡片堆。小孩能点 Dismiss，我能点「在 Grafana 打开」。」',
        filedBy: '来信人 · 家里树莓派太多的家长',
      },
      cron: {
        source: '@cron-daily',
        quote:
          '「无声失败的备份，变成了带 Retry 按钮的卡片。备份脚本里多十行就搞定了。」',
        filedBy: '来信人 · 一个不再写事故复盘的系统管理员',
      },
    },

    selfHost: {
      sectionMarker: '§ 05',
      label: '自带服务器',
      title: '你的数据、你的主机、你的规矩。',
      body:
        '整个服务端就是一个 Go 二进制加一个 PostgreSQL。没有 telemetry、没有 license server、不 phone home。复制 compose 文件，设一个 API key，就这样。',
      byline: '两个文件，四分钟。',
      ctaLabel: '阅读自托管指南 →',
    },

    openSource: {
      sectionMarker: '§ 06',
      label: '明面上的代码',
      title: '每一行，都能读到。',
      body:
        'Dingit 是一个个人副业项目，以宽松许可证开源。服务端、App、CLI，甚至你现在看的这个网站 —— 同一个仓库，同一段 commit 历史，同一个 Issue 追踪器。',
      licenseLabel: '许可证',
      licenseValue: 'MIT',
      sourceLabel: '源码',
      sourceValue: 'github.com/wuyuxiangX/dingit',
      roadmapLabel: '路线图',
      roadmapValue: 'Linear（公开）',
      authorLabel: '作者',
      authorValue: '@wuyuxiangX',
    },

    quickLinks: {
      sectionMarker: '§ 07',
      label: '从这里开始',
      title: '四个入口。',
      quickstart: {
        title: '5 分钟快速上手',
        body: 'curl → App 响铃 → callback，一次跑通。',
      },
      cliReference: {
        title: 'CLI 参考',
        body: '每个子命令、每个 flag，附完整示例。',
      },
      selfHost: {
        title: '自托管指南',
        body: 'docker-compose、systemd、云平台，选一个。',
      },
      apiReference: {
        title: 'API 参考',
        body: 'OpenAPI 驱动，不离开页面就能 Try it out。',
      },
    },

    colophon: {
      title: '版权页',
      setInLine: '标题用 DM Serif Display，正文用 Plus Jakarta Sans。',
      builtWithLine:
        '构建于 Next.js 16、Fumadocs 16、Tailwind CSS v4、TypeScript。',
      hostingLine:
        '由一个小小的自托管容器提供服务；没有 CDN 追踪、没有 analytics cookie、没有第三方字体。',
      licenseLine:
        'Dingit 以 MIT 许可证发布。这个页面的源码和产品本身放在同一个仓库。',
      signature: '一个由 @wuyuxiangX 维护的个人副业项目。发自杭州。',
      docsLabel: '文档',
      githubLabel: 'GitHub',
      changelogLabel: '更新日志',
      roadmapLabel: '路线图',
    },
  },
};
