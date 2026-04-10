import Link from 'next/link';
import {
  ArrowRightIcon,
  BellIcon,
  BookOpenIcon,
  CodeIcon,
  TerminalIcon,
  ZapIcon,
} from 'lucide-react';
import type { Locale } from '@/lib/i18n';
import { home } from '@/lib/dict';

export default async function HomePage({
  params,
}: PageProps<'/[lang]'>) {
  const { lang } = await params;
  const t = home[lang as Locale] ?? home.en;
  const prefix = `/${lang}`;

  return (
    <main className="flex flex-1 flex-col">
      {/* Hero */}
      <section className="relative flex flex-col items-center justify-center px-6 pt-24 pb-20 text-center md:pt-32 md:pb-28">
        <div className="inline-flex items-center gap-2 rounded-full border border-fd-border bg-fd-muted px-4 py-1.5 text-xs font-semibold tracking-wider uppercase text-fd-muted-foreground">
          <BellIcon className="size-3.5 text-fd-primary" strokeWidth={2.5} />
          {t.badge}
        </div>
        <h1
          className="mt-8 max-w-3xl text-5xl leading-[1.05] tracking-tight text-fd-foreground md:text-6xl lg:text-7xl"
          style={{ fontFamily: 'var(--font-display), serif' }}
        >
          {t.heroTitleLine1}
          <br />
          {t.heroTitleLine2}
        </h1>
        <p className="mt-6 max-w-2xl text-balance text-lg text-fd-muted-foreground md:text-xl">
          {t.heroSubtitle}
        </p>
        <div className="mt-10 flex flex-wrap items-center justify-center gap-3">
          <Link
            href={`${prefix}/docs`}
            className="inline-flex items-center gap-2 rounded-full bg-fd-primary px-6 py-3 text-sm font-semibold text-fd-primary-foreground shadow-sm transition hover:opacity-90"
          >
            {t.ctaPrimary}
            <ArrowRightIcon className="size-4" />
          </Link>
          <Link
            href="https://github.com/wuyuxiangX/dingit"
            className="inline-flex items-center gap-2 rounded-full border border-fd-border bg-fd-card px-6 py-3 text-sm font-semibold text-fd-foreground transition hover:bg-fd-muted"
          >
            {t.ctaSecondary}
          </Link>
        </div>
      </section>

      {/* Value props */}
      <section className="mx-auto w-full max-w-5xl px-6 pb-16">
        <div className="grid gap-4 md:grid-cols-3">
          <FeatureCard
            icon={<ZapIcon className="size-5" strokeWidth={2.25} />}
            title={t.features.interactive.title}
            body={t.features.interactive.body}
          />
          <FeatureCard
            icon={<BellIcon className="size-5" strokeWidth={2.25} />}
            title={t.features.threeClients.title}
            body={t.features.threeClients.body}
          />
          <FeatureCard
            icon={<CodeIcon className="size-5" strokeWidth={2.25} />}
            title={t.features.selfHosted.title}
            body={t.features.selfHosted.body}
          />
        </div>
      </section>

      {/* Quick links */}
      <section className="mx-auto w-full max-w-5xl px-6 pb-24">
        <h2
          className="mb-6 text-2xl font-normal tracking-tight text-fd-foreground"
          style={{ fontFamily: 'var(--font-display), serif' }}
        >
          {t.startHere}
        </h2>
        <div className="grid gap-3 sm:grid-cols-2">
          <QuickLink
            href={`${prefix}/docs/getting-started/first-notification`}
            icon={<ZapIcon className="size-4" />}
            title={t.quickLinks.quickstart.title}
            body={t.quickLinks.quickstart.body}
          />
          <QuickLink
            href={`${prefix}/docs/cli`}
            icon={<TerminalIcon className="size-4" />}
            title={t.quickLinks.cliReference.title}
            body={t.quickLinks.cliReference.body}
          />
          <QuickLink
            href={`${prefix}/docs/server/deploy-docker`}
            icon={<BookOpenIcon className="size-4" />}
            title={t.quickLinks.selfHost.title}
            body={t.quickLinks.selfHost.body}
          />
          <QuickLink
            href={`${prefix}/docs/api/reference`}
            icon={<CodeIcon className="size-4" />}
            title={t.quickLinks.apiReference.title}
            body={t.quickLinks.apiReference.body}
          />
        </div>
      </section>
    </main>
  );
}

function FeatureCard({
  icon,
  title,
  body,
}: {
  icon: React.ReactNode;
  title: string;
  body: string;
}) {
  return (
    <div className="rounded-2xl border border-fd-border bg-fd-card p-6 transition hover:border-fd-primary/30">
      <div className="mb-4 inline-flex size-10 items-center justify-center rounded-lg bg-fd-muted text-fd-primary">
        {icon}
      </div>
      <h3 className="mb-2 text-base font-semibold text-fd-foreground">
        {title}
      </h3>
      <p className="text-sm leading-relaxed text-fd-muted-foreground">{body}</p>
    </div>
  );
}

function QuickLink({
  href,
  icon,
  title,
  body,
}: {
  href: string;
  icon: React.ReactNode;
  title: string;
  body: string;
}) {
  return (
    <Link
      href={href}
      className="group flex items-start gap-3 rounded-xl border border-fd-border bg-fd-card p-4 transition hover:border-fd-primary/40 hover:bg-fd-muted"
    >
      <span className="mt-0.5 flex size-7 shrink-0 items-center justify-center rounded-md bg-fd-muted text-fd-primary group-hover:bg-fd-card">
        {icon}
      </span>
      <span className="flex-1">
        <span className="flex items-center gap-1.5 text-sm font-semibold text-fd-foreground">
          {title}
          <ArrowRightIcon className="size-3.5 -translate-x-1 opacity-0 transition group-hover:translate-x-0 group-hover:opacity-100" />
        </span>
        <span className="mt-0.5 block text-xs text-fd-muted-foreground">
          {body}
        </span>
      </span>
    </Link>
  );
}
