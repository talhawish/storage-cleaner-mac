/**
 * No-op service worker endpoint. Some dev tooling / HMR clients probe for
 * Firebase messaging service workers; we don't ship one, so return 204 to
 * silence the [Vue Router warn]: No match found noise without leaving a
 * dangling 404 in the logs.
 */
export default defineEventHandler((event) => {
  setResponseStatus(event, 204)
  return null
})
