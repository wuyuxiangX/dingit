import Link from 'next/link';
import {
  ArrowRightIcon,
  ArrowUpRightIcon,
  BellIcon,
  BookOpenIcon,
  CodeIcon,
  TerminalIcon,
  ZapIcon,
} from 'lucide-react';
import type { Locale } from '@/lib/i18n';
import { home } from '@/lib/dict';

/*
 * The Dingit landing — shaped as a small editorial zine about
 * interactive notifications. Section markers behave like magazine
 * furniture (§ 01, § 02, ...), one pull quote, four-step "anatomy"
 * essay with a real footnote, field dispatches instead of generic
 * use-case cards, and a colophon in place of the usual footer.
 *
 * Composition decisions worth preserving:
 *   1. Every section lives inside the same 5xl-max grid so the
 *      rhythm of the page holds together top to bottom.
 *   2. Odd sections stay on the paper background, even sections
 *      flip to the warm muted tint to create a page-turning feel
 *      without loud color changes.
 *   3. Asymmetric 2/5 + 3/5 grids on desktop, single column on
 *      mobile. We never use 50/50 — it looks like every other SaaS.
 *   4. Typography pairing is DM Serif Display (titles, numbers,
 *      pull quote) + Plus Jakarta Sans (body). The whole page lives
 *      or dies on this pairing staying consistent.
 *   5. No JS interactivity on the marketing surface — everything
 *      renders as a Server Component. Keeps the bundle at zero.
 */

const INSTALL_CURL = `curl -sSf https://dingit.me/install.sh | sh`;

const INSTALL_DOCKER = `curl -O https://dingit.me/docker-compose.yml
docker compose up -d`;

const INSTALL_BINARY = `curl -LO https://github.com/wuyuxiangX/dingit/\\
  releases/latest/download/dingit-server-linux-amd64.tar.gz
tar -xzf dingit-server-linux-amd64.tar.gz
./dingit-server`;

const DOCKER_COMPOSE_YAML = `services:
  postgres:
    image: postgres:17-alpine
    environment:
      POSTGRES_PASSWORD: dingit
    volumes:
      - ./data/pg:/var/lib/postgresql/data

  dingit:
    image: ghcr.io/wuyuxiangx/dingit-server:latest
    environment:
      DATABASE_URL: postgres://postgres:dingit@postgres/dingit
      API_KEY_FILE: /secrets/api-key
    ports:
      - "8080:8080"
    depends_on: [postgres]`;

const GITHUB_URL = 'https://github.com/wuyuxiangX/dingit';
const ROADMAP_URL = 'https://linear.app/wyx/project/dingit-a475861ca11e';

export default async function HomePage({
  params,
}: PageProps<'/[lang]'>) {
  const { lang } = await params;
  const t = home[lang as Locale] ?? home.en;
  const prefix = `/${lang}`;

  return (
    <main className="flex flex-1 flex-col">
      {/* ────────────────── Hero — editorial masthead ────────────────── */}
      <section className="relative border-b border-fd-border">
        <div className="mx-auto max-w-5xl px-6 pt-20 pb-24 md:pt-28 md:pb-32">
          <div className="mb-12 flex items-baseline gap-3">
            <BellIcon
              className="size-4 text-fd-primary"
              strokeWidth={2.25}
              aria-hidden
            />
            <span className="text-[0.6875rem] font-semibold uppercase tracking-[0.24em] text-fd-muted-foreground">
              {t.hero.eyebrow}
            </span>
          </div>

          <h1 className="font-display text-[clamp(2.75rem,7vw,6.25rem)] leading-[0.95] tracking-[-0.02em] text-fd-foreground">
            {t.hero.titleLine1}
            <br />
            <span className="italic text-fd-primary">{t.hero.titleLine2}</span>
          </h1>

          <p className="mt-10 max-w-2xl text-lg leading-[1.65] text-fd-muted-foreground md:text-xl">
            {t.hero.subtitle}
          </p>

          <div className="mt-12 flex flex-wrap items-center gap-x-8 gap-y-4">
            <Link
              href={`${prefix}/docs`}
              className="group inline-flex items-center gap-2 rounded-full bg-fd-primary px-6 py-3 text-sm font-semibold text-fd-primary-foreground shadow-sm transition hover:opacity-90"
            >
              {t.hero.ctaPrimary}
              <ArrowRightIcon className="size-4 transition group-hover:translate-x-0.5" />
            </Link>
            <Link
              href={GITHUB_URL}
              target="_blank"
              rel="noreferrer"
              className="group inline-flex items-center gap-1.5 text-sm font-semibold text-fd-foreground underline decoration-fd-border decoration-1 underline-offset-[6px] transition hover:decoration-fd-primary"
            >
              {t.hero.ctaSecondary}
              <ArrowUpRightIcon className="size-3.5 transition group-hover:-translate-y-0.5 group-hover:translate-x-0.5" />
            </Link>
          </div>
        </div>
      </section>

      {/* ────────────────── § 01 First Principles ────────────────── */}
      <section className="relative border-b border-fd-border">
        <div className="mx-auto max-w-5xl px-6 py-24 md:py-28">
          <SectionMarker marker={t.essay.sectionMarker} label={t.essay.label} />

          <blockquote className="mx-auto mt-16 mb-20 max-w-3xl text-center">
            <p className="font-display text-3xl italic leading-[1.15] text-fd-foreground text-balance md:text-[2.75rem]">
              {t.essay.pullQuote}
            </p>
            <cite className="mt-8 block text-[0.6875rem] uppercase tracking-[0.24em] text-fd-muted-foreground not-italic">
              {t.essay.pullQuoteAttribution}
            </cite>
          </blockquote>

          <div className="mt-16 grid gap-14 md:grid-cols-3 md:gap-10">
            <EssayColumnView col={t.essay.interactive} />
            <EssayColumnView col={t.essay.threeClients} />
            <EssayColumnView col={t.essay.selfHosted} />
          </div>
        </div>
      </section>

      {/* ────────────────── § 02 Anatomy of a Ding ────────────────── */}
      <section className="relative border-b border-fd-border bg-fd-muted/50">
        <div className="mx-auto max-w-5xl px-6 py-24 md:py-28">
          <SectionMarker
            marker={t.anatomy.sectionMarker}
            label={t.anatomy.label}
          />

          <div className="mt-14 grid gap-12 md:grid-cols-5 md:gap-x-16">
            <div className="md:col-span-2">
              <h2 className="font-display text-4xl leading-[1.05] tracking-[-0.015em] text-fd-foreground md:text-5xl lg:text-6xl">
                {t.anatomy.title}
              </h2>
            </div>
            <div className="md:col-span-3">
              <p className="text-[1.0625rem] leading-[1.75] text-fd-foreground first-letter:float-left first-letter:mr-3 first-letter:mt-1 first-letter:font-display first-letter:text-[4.5rem] first-letter:leading-[0.8] first-letter:text-fd-primary">
                {t.anatomy.intro}
              </p>
            </div>
          </div>

          <ol className="mt-16 space-y-12 md:ml-[calc(40%+4rem)]">
            <AnatomyStepRow step={t.anatomy.step1} />
            <AnatomyStepRow step={t.anatomy.step2} />
            <AnatomyStepRow step={t.anatomy.step3} />
            <AnatomyStepRow step={t.anatomy.step4} />
          </ol>

          <aside className="mt-16 border-t border-fd-border pt-6 md:ml-[calc(40%+4rem)]">
            <p className="text-xs leading-relaxed text-fd-muted-foreground">
              {t.anatomy.footnote}
            </p>
          </aside>
        </div>
      </section>

      {/* ────────────────── § 03 Install ────────────────── */}
      <section className="relative border-b border-fd-border">
        <div className="mx-auto max-w-5xl px-6 py-24 md:py-28">
          <SectionMarker
            marker={t.install.sectionMarker}
            label={t.install.label}
          />

          <div className="mt-14 grid gap-12 md:grid-cols-5 md:gap-x-16">
            <div className="md:col-span-2">
              <h2 className="font-display text-4xl leading-[1.05] tracking-[-0.015em] text-fd-foreground md:text-5xl lg:text-6xl">
                {t.install.title}
              </h2>
              <p className="mt-8 max-w-md text-[0.9375rem] leading-[1.7] text-fd-muted-foreground">
                {t.install.body}
              </p>
            </div>

            <div className="md:col-span-3">
              <div className="space-y-10">
                <InstallSnippet
                  label={t.install.curlLabel}
                  subtitle={t.install.curlSubtitle}
                  code={INSTALL_CURL}
                />
                <InstallSnippet
                  label={t.install.dockerLabel}
                  subtitle={t.install.dockerSubtitle}
                  code={INSTALL_DOCKER}
                />
                <InstallSnippet
                  label={t.install.binaryLabel}
                  subtitle={t.install.binarySubtitle}
                  code={INSTALL_BINARY}
                />
              </div>
              <p className="mt-10 text-sm italic leading-relaxed text-fd-muted-foreground">
                {t.install.postamble}
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ────────────────── § 04 Field Dispatches ────────────────── */}
      <section className="relative border-b border-fd-border bg-fd-muted/50">
        <div className="mx-auto max-w-5xl px-6 py-24 md:py-28">
          <SectionMarker
            marker={t.dispatches.sectionMarker}
            label={t.dispatches.label}
          />

          <div className="mt-14 grid gap-12 md:grid-cols-5 md:gap-x-16">
            <div className="md:col-span-2">
              <h2 className="font-display text-4xl leading-[1.05] tracking-[-0.015em] text-fd-foreground md:text-5xl lg:text-6xl">
                {t.dispatches.title}
              </h2>
              <p className="mt-8 max-w-md text-[0.9375rem] leading-[1.7] text-fd-muted-foreground">
                {t.dispatches.intro}
              </p>
            </div>

            <div className="md:col-span-3 divide-y divide-fd-border">
              <DispatchCard d={t.dispatches.ci} />
              <DispatchCard d={t.dispatches.training} />
              <DispatchCard d={t.dispatches.homeLab} />
              <DispatchCard d={t.dispatches.cron} />
            </div>
          </div>
        </div>
      </section>

      {/* ────────────────── § 05 Bring Your Own Server ────────────────── */}
      <section className="relative border-b border-fd-border">
        <div className="mx-auto max-w-5xl px-6 py-24 md:py-28">
          <SectionMarker
            marker={t.selfHost.sectionMarker}
            label={t.selfHost.label}
          />

          <div className="mt-14 grid gap-12 md:grid-cols-5 md:gap-x-16">
            <div className="md:col-span-2">
              <h2 className="font-display text-4xl leading-[1.05] tracking-[-0.015em] text-fd-foreground md:text-5xl lg:text-6xl">
                {t.selfHost.title}
              </h2>
              <p className="mt-8 text-[0.9375rem] leading-[1.7] text-fd-muted-foreground">
                {t.selfHost.body}
              </p>
              <p className="mt-6 font-display text-2xl italic text-fd-primary md:text-3xl">
                {t.selfHost.byline}
              </p>
              <Link
                href={`${prefix}/docs/server/deploy-docker`}
                className="mt-8 inline-flex items-center gap-1.5 text-sm font-semibold text-fd-foreground underline decoration-fd-border decoration-1 underline-offset-[6px] transition hover:decoration-fd-primary"
              >
                {t.selfHost.ctaLabel}
              </Link>
            </div>

            <div className="md:col-span-3">
              <figure className="rounded-lg border border-fd-border bg-fd-card shadow-sm">
                <figcaption className="flex items-center gap-2 border-b border-fd-border px-4 py-2.5">
                  <div className="flex gap-1.5">
                    <span className="size-2.5 rounded-full bg-fd-muted" />
                    <span className="size-2.5 rounded-full bg-fd-muted" />
                    <span className="size-2.5 rounded-full bg-fd-muted" />
                  </div>
                  <span className="ml-2 font-mono text-xs text-fd-muted-foreground">
                    docker-compose.yml
                  </span>
                </figcaption>
                <pre className="overflow-x-auto p-5 text-[0.8125rem] leading-[1.7] text-fd-foreground">
                  <code className="font-mono">{DOCKER_COMPOSE_YAML}</code>
                </pre>
              </figure>
            </div>
          </div>
        </div>
      </section>

      {/* ────────────────── § 06 Built in Public — ledger ────────────────── */}
      <section className="relative border-b border-fd-border bg-fd-muted/50">
        <div className="mx-auto max-w-5xl px-6 py-24 md:py-28">
          <SectionMarker
            marker={t.openSource.sectionMarker}
            label={t.openSource.label}
          />

          <div className="mt-14 grid gap-12 md:grid-cols-5 md:gap-x-16">
            <div className="md:col-span-2">
              <h2 className="font-display text-4xl leading-[1.05] tracking-[-0.015em] text-fd-foreground md:text-5xl lg:text-6xl">
                {t.openSource.title}
              </h2>
              <p className="mt-8 max-w-md text-[0.9375rem] leading-[1.7] text-fd-muted-foreground">
                {t.openSource.body}
              </p>
            </div>

            <dl className="md:col-span-3 divide-y divide-fd-border border-y border-fd-border">
              <LedgerRow
                label={t.openSource.licenseLabel}
                value={t.openSource.licenseValue}
              />
              <LedgerRow
                label={t.openSource.sourceLabel}
                value={t.openSource.sourceValue}
                href={GITHUB_URL}
              />
              <LedgerRow
                label={t.openSource.roadmapLabel}
                value={t.openSource.roadmapValue}
                href={ROADMAP_URL}
              />
              <LedgerRow
                label={t.openSource.authorLabel}
                value={t.openSource.authorValue}
                href="https://github.com/wuyuxiangX"
              />
            </dl>
          </div>
        </div>
      </section>

      {/* ────────────────── § 07 Start Here ────────────────── */}
      <section className="relative border-b border-fd-border">
        <div className="mx-auto max-w-5xl px-6 py-24 md:py-28">
          <SectionMarker
            marker={t.quickLinks.sectionMarker}
            label={t.quickLinks.label}
          />

          <h2 className="mt-10 font-display text-4xl leading-[1.05] tracking-[-0.015em] text-fd-foreground md:text-5xl lg:text-6xl">
            {t.quickLinks.title}
          </h2>

          <div className="mt-12 grid gap-3 sm:grid-cols-2">
            <QuickLinkCard
              href={`${prefix}/docs/getting-started/first-notification`}
              icon={<ZapIcon className="size-4" />}
              title={t.quickLinks.quickstart.title}
              body={t.quickLinks.quickstart.body}
            />
            <QuickLinkCard
              href={`${prefix}/docs/cli`}
              icon={<TerminalIcon className="size-4" />}
              title={t.quickLinks.cliReference.title}
              body={t.quickLinks.cliReference.body}
            />
            <QuickLinkCard
              href={`${prefix}/docs/server/deploy-docker`}
              icon={<BookOpenIcon className="size-4" />}
              title={t.quickLinks.selfHost.title}
              body={t.quickLinks.selfHost.body}
            />
            <QuickLinkCard
              href={`${prefix}/docs/api/reference`}
              icon={<CodeIcon className="size-4" />}
              title={t.quickLinks.apiReference.title}
              body={t.quickLinks.apiReference.body}
            />
          </div>
        </div>
      </section>

      {/* ────────────────── Colophon ────────────────── */}
      <footer className="relative bg-fd-muted/50">
        <div className="mx-auto max-w-5xl px-6 py-20 md:py-24">
          <h2 className="font-display text-4xl italic leading-none text-fd-foreground md:text-5xl">
            {t.colophon.title}
          </h2>

          <div className="mt-12 grid gap-14 md:grid-cols-5 md:gap-x-16">
            <div className="space-y-4 text-[0.9375rem] leading-[1.8] text-fd-muted-foreground md:col-span-3">
              <p>{t.colophon.setInLine}</p>
              <p>{t.colophon.builtWithLine}</p>
              <p>{t.colophon.hostingLine}</p>
              <p>{t.colophon.licenseLine}</p>
            </div>

            <div className="md:col-span-2">
              <div className="divide-y divide-fd-border border-y border-fd-border">
                <ColophonLink
                  href={`${prefix}/docs`}
                  label={t.colophon.docsLabel}
                />
                <ColophonLink
                  href={GITHUB_URL}
                  label={t.colophon.githubLabel}
                  external
                />
                <ColophonLink
                  href={`${prefix}/docs/reference/changelog`}
                  label={t.colophon.changelogLabel}
                />
                <ColophonLink
                  href={ROADMAP_URL}
                  label={t.colophon.roadmapLabel}
                  external
                />
              </div>
            </div>
          </div>

          <div className="mt-16 flex flex-wrap items-baseline justify-between gap-6 border-t border-fd-border pt-6">
            <p className="max-w-md text-[0.6875rem] uppercase tracking-[0.2em] text-fd-muted-foreground">
              {t.colophon.signature}
            </p>
            <p className="font-display text-2xl italic text-fd-primary">
              Dingit · MMXXVI
            </p>
          </div>
        </div>
      </footer>
    </main>
  );
}

// ── Helper components ──────────────────────────────────────────────────────

function SectionMarker({ marker, label }: { marker: string; label: string }) {
  return (
    <div className="flex items-baseline gap-4">
      <span className="font-display text-3xl leading-none text-fd-primary md:text-4xl">
        {marker}
      </span>
      <div aria-hidden className="h-px flex-1 bg-fd-border" />
      <span className="text-[0.6875rem] font-semibold uppercase tracking-[0.24em] text-fd-muted-foreground">
        {label}
      </span>
    </div>
  );
}

function EssayColumnView({
  col,
}: {
  col: { number: string; title: string; body: string };
}) {
  return (
    <article>
      <span className="font-display text-3xl italic leading-none text-fd-primary">
        {col.number}
      </span>
      <h3 className="mt-5 font-display text-[1.625rem] leading-[1.15] text-fd-foreground">
        {col.title}
      </h3>
      <p className="mt-4 text-[0.9375rem] leading-[1.75] text-fd-muted-foreground">
        {col.body}
      </p>
    </article>
  );
}

function AnatomyStepRow({
  step,
}: {
  step: { n: string; title: string; body: string };
}) {
  return (
    <li className="grid grid-cols-[auto_1fr] gap-7">
      <span className="font-display text-[3.25rem] leading-[0.85] text-fd-primary md:text-6xl">
        {step.n}
      </span>
      <div>
        <h3 className="font-display text-2xl leading-tight text-fd-foreground md:text-[1.75rem]">
          {step.title}
        </h3>
        <p className="mt-3 text-[0.9375rem] leading-[1.75] text-fd-muted-foreground">
          {step.body}
        </p>
      </div>
    </li>
  );
}

function InstallSnippet({
  label,
  subtitle,
  code,
}: {
  label: string;
  subtitle: string;
  code: string;
}) {
  return (
    <figure>
      <figcaption className="mb-3 flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 border-b border-fd-border pb-2">
        <span className="font-display text-lg text-fd-foreground">{label}</span>
        <span className="text-[0.6875rem] uppercase tracking-[0.2em] text-fd-muted-foreground">
          {subtitle}
        </span>
      </figcaption>
      <pre className="overflow-x-auto rounded-md border border-fd-border bg-fd-card p-4 text-[0.8125rem] leading-[1.7] text-fd-foreground">
        <code className="font-mono">{code}</code>
      </pre>
    </figure>
  );
}

function DispatchCard({
  d,
}: {
  d: { source: string; quote: string; filedBy: string };
}) {
  return (
    <article className="py-9 first:pt-0 last:pb-0">
      <div className="mb-4 font-mono text-xs font-semibold tracking-wide text-fd-primary">
        {d.source}
      </div>
      <blockquote className="font-display text-[1.375rem] leading-[1.35] text-fd-foreground md:text-2xl">
        {d.quote}
      </blockquote>
      <div className="mt-5 text-[0.6875rem] uppercase tracking-[0.2em] text-fd-muted-foreground">
        {d.filedBy}
      </div>
    </article>
  );
}

function LedgerRow({
  label,
  value,
  href,
}: {
  label: string;
  value: string;
  href?: string;
}) {
  const valueNode = href ? (
    <a
      href={href}
      target="_blank"
      rel="noreferrer"
      className="group inline-flex items-baseline gap-1.5 text-fd-foreground underline decoration-fd-border decoration-1 underline-offset-[6px] transition hover:decoration-fd-primary hover:text-fd-primary"
    >
      {value}
      <ArrowUpRightIcon className="size-3.5 translate-y-[-1px] transition group-hover:-translate-y-[3px] group-hover:translate-x-0.5" />
    </a>
  ) : (
    <span className="text-fd-foreground">{value}</span>
  );

  return (
    <div className="grid grid-cols-[8rem_1fr] items-baseline gap-4 py-5 md:grid-cols-[10rem_1fr]">
      <dt className="text-[0.6875rem] uppercase tracking-[0.2em] text-fd-muted-foreground">
        {label}
      </dt>
      <dd className="font-display text-xl md:text-2xl">{valueNode}</dd>
    </div>
  );
}

function QuickLinkCard({
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
      className="group flex items-start gap-4 rounded-xl border border-fd-border bg-fd-card p-5 transition hover:border-fd-primary/40 hover:bg-fd-muted"
    >
      <span className="mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-md bg-fd-muted text-fd-primary transition group-hover:bg-fd-card">
        {icon}
      </span>
      <span className="flex-1">
        <span className="flex items-center gap-1.5 text-sm font-semibold text-fd-foreground">
          {title}
          <ArrowRightIcon className="size-3.5 -translate-x-1 opacity-0 transition group-hover:translate-x-0 group-hover:opacity-100" />
        </span>
        <span className="mt-1 block text-xs leading-relaxed text-fd-muted-foreground">
          {body}
        </span>
      </span>
    </Link>
  );
}

function ColophonLink({
  href,
  label,
  external,
}: {
  href: string;
  label: string;
  external?: boolean;
}) {
  const externalAttrs = external
    ? { target: '_blank' as const, rel: 'noreferrer' as const }
    : {};
  return (
    <Link
      href={href}
      {...externalAttrs}
      className="group flex items-baseline justify-between py-3 text-sm font-semibold text-fd-foreground transition hover:text-fd-primary"
    >
      <span>{label}</span>
      <span className="text-fd-muted-foreground transition group-hover:translate-x-1 group-hover:text-fd-primary">
        {external ? '↗' : '→'}
      </span>
    </Link>
  );
}
