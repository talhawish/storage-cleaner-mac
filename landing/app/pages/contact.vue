<script setup lang="ts">
usePageSeo({
  title: 'Contact us',
  description:
    'Reach the Storage Cleaner for Developers team. Support, bug reports, feature requests, and press — all in one place.',
  image: '/og-image-contact.png',
  path: '/contact'
})

const form = reactive({
  name: '',
  email: '',
  topic: 'support',
  message: '',
  consent: false
})

const status = ref<'idle' | 'sending' | 'sent' | 'error'>('idle')

const submit = async () => {
  if (!form.consent || !form.email || !form.message) {
    status.value = 'error'
    return
  }
  status.value = 'sending'
  // Open a pre-filled mail client as the contact transport.
  const subject = encodeURIComponent(`[${form.topic}] Storage Cleaner — ${form.name || 'New message'}`)
  const body = encodeURIComponent(
    `From: ${form.name} <${form.email}>\nTopic: ${form.topic}\n\n${form.message}\n\n— Sent from storagecleaner.app/contact`
  )
  const href = `mailto:support@storagecleaner.app?subject=${subject}&body=${body}`
  if (typeof window !== 'undefined') window.location.href = href
  status.value = 'sent'
}

const channels = [
  {
    label: 'Support',
    email: 'support@storagecleaner.app',
    body: 'Bugs, scans gone wrong, questions about a cleanup operation.',
    cta: 'Email support'
  },
  {
    label: 'Feature requests',
    email: 'feedback@storagecleaner.app',
    body: 'A storage domain we should cover, a UI tweak, a missing command.',
    cta: 'Send a request'
  },
  {
    label: 'Press & partnerships',
    email: 'press@storagecleaner.app',
    body: 'Reviews, interviews, conference talks, Mac App Store features.',
    cta: 'Get in touch'
  }
] as const
</script>

<template>
  <article class="bg-white">
    <header class="border-b border-ink-200 bg-ink-50/40 py-16 sm:py-20">
      <div class="container-page">
        <NuxtLink to="/" class="text-xs text-ink-500 hover:text-ink-900">
          ← Back to home
        </NuxtLink>
        <p class="eyebrow mt-6">Get in touch</p>
        <h1 class="heading-section mt-4 text-balance">We answer every message.</h1>
        <p class="lede mt-4 max-w-2xl text-pretty">
          A real person reads every email. Pick the channel that fits, or use
          the form — both reach the same inbox.
        </p>
      </div>
    </header>

    <div class="container-page grid gap-12 py-16 sm:py-20 lg:grid-cols-[1fr_1.2fr]">
      <section>
        <h2 class="text-lg font-semibold text-ink-900">Direct channels</h2>
        <ul class="mt-6 space-y-3">
          <li
            v-for="channel in channels"
            :key="channel.label"
            class="rounded-2xl border border-ink-200 bg-white p-5"
          >
            <div class="flex items-center justify-between gap-3">
              <h3 class="text-sm font-semibold text-ink-900">{{ channel.label }}</h3>
              <a
                :href="`mailto:${channel.email}`"
                class="text-xs font-medium text-brand-600 hover:text-brand-700"
              >
                {{ channel.email }}
              </a>
            </div>
            <p class="mt-2 text-sm leading-relaxed text-ink-600">{{ channel.body }}</p>
            <a
              :href="`mailto:${channel.email}`"
              class="btn-secondary mt-4 shrink-0 py-2 text-[12px]"
            >
              {{ channel.cta }}
            </a>
          </li>
        </ul>

        <div class="mt-8 rounded-2xl border border-ink-200 bg-ink-50/50 p-5 text-sm leading-relaxed text-ink-600">
          <p class="font-medium text-ink-900">Response time</p>
          <p class="mt-1.5">
            We typically reply within 1 business day. For time-sensitive Mac
            App Store issues (e.g. a failed purchase), write
            <a href="mailto:support@storagecleaner.app" class="text-ink-900 underline decoration-ink-300 underline-offset-4 hover:decoration-ink-700">
              support@storagecleaner.app
            </a>
            and include the App Store receipt ID.
          </p>
        </div>
      </section>

      <section>
        <form
          class="rounded-2xl border border-ink-200 bg-white p-6 sm:p-8"
          @submit.prevent="submit"
        >
          <h2 class="text-lg font-semibold text-ink-900">Send us a note</h2>
          <p class="mt-2 text-sm text-ink-600">
            We open your mail client with the message pre-filled — your data
            never touches a third-party form service.
          </p>

          <div class="mt-6 grid gap-4 sm:grid-cols-2">
            <label class="flex flex-col gap-1.5">
              <span class="text-xs font-medium text-ink-700">Your name</span>
              <input
                v-model="form.name"
                type="text"
                autocomplete="name"
                placeholder="Ada Lovelace"
                class="rounded-lg border border-ink-200 bg-white px-3.5 py-2.5 text-sm text-ink-900 placeholder:text-ink-400 focus:border-ink-700 focus:outline-none focus:ring-2 focus:ring-ink-900/10"
              />
            </label>
            <label class="flex flex-col gap-1.5">
              <span class="text-xs font-medium text-ink-700">Email *</span>
              <input
                v-model="form.email"
                type="email"
                required
                autocomplete="email"
                placeholder="you@example.com"
                class="rounded-lg border border-ink-200 bg-white px-3.5 py-2.5 text-sm text-ink-900 placeholder:text-ink-400 focus:border-ink-700 focus:outline-none focus:ring-2 focus:ring-ink-900/10"
              />
            </label>
          </div>

          <label class="mt-4 flex flex-col gap-1.5">
            <span class="text-xs font-medium text-ink-700">Topic</span>
            <select
              v-model="form.topic"
              class="rounded-lg border border-ink-200 bg-white px-3.5 py-2.5 text-sm text-ink-900 focus:border-ink-700 focus:outline-none focus:ring-2 focus:ring-ink-900/10"
            >
              <option value="support">Support</option>
              <option value="bug">Bug report</option>
              <option value="feature">Feature request</option>
              <option value="press">Press &amp; partnerships</option>
              <option value="other">Other</option>
            </select>
          </label>

          <label class="mt-4 flex flex-col gap-1.5">
            <span class="text-xs font-medium text-ink-700">Message *</span>
            <textarea
              v-model="form.message"
              required
              rows="6"
              placeholder="What\u2019s on your mind?"
              class="rounded-lg border border-ink-200 bg-white px-3.5 py-2.5 text-sm text-ink-900 placeholder:text-ink-400 focus:border-ink-700 focus:outline-none focus:ring-2 focus:ring-ink-900/10"
            />
          </label>

          <label class="mt-5 flex items-start gap-2.5 text-[13px] text-ink-600">
            <input
              v-model="form.consent"
              type="checkbox"
              class="mt-0.5 size-4 rounded border-ink-300 text-ink-900 focus:ring-ink-900/20"
            />
            <span>
              I understand my message will be sent to support@storagecleaner.app
              via my mail client, and that the content I type is handled under
              the
              <NuxtLink to="/privacy" class="text-ink-900 underline decoration-ink-300 underline-offset-4 hover:decoration-ink-700">
                Privacy Policy
              </NuxtLink>.
            </span>
          </label>

          <div class="mt-6 flex flex-wrap items-center justify-between gap-3">
            <p
              v-if="status === 'error'"
              class="text-xs text-amber-700"
            >
              Please fill in your email, a message, and tick the consent box.
            </p>
            <p
              v-else-if="status === 'sent'"
              class="text-xs text-emerald-700"
            >
              Your mail client is opening — send the draft to reach us.
            </p>
            <p v-else class="text-xs text-ink-500">
              We\u2019ll only use your details to reply to this message.
            </p>
            <button
              type="submit"
              class="btn-primary shrink-0 px-5 py-2.5 text-sm"
              :disabled="status === 'sending'"
            >
              {{ status === 'sending' ? 'Opening\u2026' : 'Send message' }}
            </button>
          </div>
        </form>
      </section>
    </div>
  </article>
</template>
