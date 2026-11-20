package com.stockmanager.stock_manager

import android.app.Notification
import android.app.Person
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * 카톡 배당 알림 1단계 시험: 카카오톡 알림이 어떤 모양으로 들어오는지 기록만 한다.
 * 서버로 보내지 않고 이 앱의 내부 파일에만 남긴다.
 *  - 증권사 채널(이름에 '증권' 등) 알림은 내용까지 저장
 *  - 그 밖의 카톡 알림은 내용 없이 구조(키 이름 · 글자 수)만 저장
 */
class KakaoNotificationListener : NotificationListenerService() {
    override fun onListenerConnected() {
        instance = this
        ProbeStore.markConnected(this)
        scanActive()
    }

    override fun onListenerDisconnected() {
        if (instance === this) instance = null
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        ProbeStore.record(this, sbn, source = "posted")
    }

    /** 지금 알림창에 있는 카톡 알림을 다시 읽는다. 새로 저장한 수 */
    fun scanActive(): Int =
        try {
            activeNotifications?.count { ProbeStore.record(this, it, source = "active") } ?: 0
        } catch (_: Exception) {
            0
        }

    companion object {
        @Volatile
        var instance: KakaoNotificationListener? = null
    }
}

object ProbeStore {
    private const val KAKAO = "com.kakao.talk"
    private const val MAX_LINES = 300
    private const val PREFS = "kakao_probe"
    private val lock = Any()
    private val recentSigs = ArrayDeque<Int>()

    private fun file(ctx: Context) = File(ctx.filesDir, "kakao_probe.jsonl")

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun markConnected(ctx: Context) {
        prefs(ctx).edit().putLong("connected_at", System.currentTimeMillis()).apply()
    }

    fun stats(ctx: Context): Map<String, Any?> {
        val p = prefs(ctx)
        return mapOf(
            "connectedAt" to p.getLong("connected_at", 0L),
            "kakaoSeen" to p.getInt("kakao_seen", 0),
            "brokerSaved" to p.getInt("broker_saved", 0),
            "lastKakaoAt" to p.getLong("last_kakao_at", 0L),
        )
    }

    fun readAll(ctx: Context): String = synchronized(lock) {
        val f = file(ctx)
        if (f.exists()) f.readText() else ""
    }

    fun clear(ctx: Context) = synchronized(lock) {
        file(ctx).delete()
        recentSigs.clear()
        prefs(ctx).edit().clear().apply()
    }

    // 알림톡 본문 첫 줄: [신한투자증권] · [한국투자] · [NH투자증권] …
    private val brokerHead = Regex("""^\s*\[[^\]]*(증권|투자)[^\]]*]""")

    private fun isBroker(vararg names: String?) = names.any { it != null && it.contains("증권") }

    /** 저장했으면 true (같은 알림이 다시 올라온 경우 등은 false) */
    fun record(ctx: Context, sbn: StatusBarNotification, source: String): Boolean {
        if (sbn.packageName != KAKAO) return false
        val n = sbn.notification ?: return false
        val ex = n.extras ?: Bundle()

        val title = ex.cs(Notification.EXTRA_TITLE)
        val conversation = ex.cs(Notification.EXTRA_CONVERSATION_TITLE)
        val subText = ex.cs(Notification.EXTRA_SUB_TEXT)
        val text = ex.cs(Notification.EXTRA_TEXT)
        val bigText = ex.cs(Notification.EXTRA_BIG_TEXT)
        val lines = ex.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.map { it.toString() }
        val messages = readMessages(ex)

        val broker = isBroker(title, conversation, subText) ||
            messages.any { isBroker(it.optString("sender")) } ||
            listOfNotNull(text, bigText).any { brokerHead.containsMatchIn(it) } ||
            messages.any { brokerHead.containsMatchIn(it.optString("text")) }

        val sig = listOf(sbn.key, title, text, bigText, messages.toString(), broker).hashCode()

        synchronized(lock) {
            val p = prefs(ctx)
            if (source == "posted") {
                p.edit()
                    .putInt("kakao_seen", p.getInt("kakao_seen", 0) + 1)
                    .putLong("last_kakao_at", System.currentTimeMillis())
                    .apply()
            }
            if (recentSigs.contains(sig)) return false
            recentSigs.addLast(sig)
            while (recentSigs.size > 100) recentSigs.removeFirst()

            val rec = JSONObject()
                .put("kind", if (broker) "broker" else "other")
                .put("source", source)
                .put("capturedAt", System.currentTimeMillis())
                .put("postTime", sbn.postTime)
                .put("id", sbn.id)
                .put("tag", sbn.tag ?: JSONObject.NULL)
                .put("channel", if (Build.VERSION.SDK_INT >= 26) n.channelId else JSONObject.NULL)
                .put("category", n.category ?: JSONObject.NULL)
                .put("group", n.group ?: JSONObject.NULL)
                .put("groupSummary", (n.flags and Notification.FLAG_GROUP_SUMMARY) != 0)
                .put("template", ex.getString(Notification.EXTRA_TEMPLATE) ?: JSONObject.NULL)
                .put("isGroupConversation", ex.getBoolean(Notification.EXTRA_IS_GROUP_CONVERSATION))
                .put("keys", extrasShape(ex))

            if (broker) {
                rec.put("title", title ?: JSONObject.NULL)
                    .put("conversationTitle", conversation ?: JSONObject.NULL)
                    .put("subText", subText ?: JSONObject.NULL)
                    .put("text", text ?: JSONObject.NULL)
                    .put("bigText", bigText ?: JSONObject.NULL)
                    .put("textLines", lines?.let { JSONArray(it) } ?: JSONObject.NULL)
                    .put("messages", JSONArray(messages))
                p.edit().putInt("broker_saved", p.getInt("broker_saved", 0) + 1).apply()
            } else {
                // 개인 대화는 내용을 남기지 않는다: 글자 수만
                rec.put(
                    "lengths",
                    JSONObject()
                        .put("title", title?.length ?: 0)
                        .put("text", text?.length ?: 0)
                        .put("bigText", bigText?.length ?: 0)
                        .put("messages", messages.size)
                        .put("lastMessage", messages.lastOrNull()?.optString("text")?.length ?: 0),
                )
            }

            val f = file(ctx)
            f.appendText(rec.toString() + "\n")
            val all = f.readLines()
            if (all.size > MAX_LINES) f.writeText(all.takeLast(MAX_LINES).joinToString("\n", postfix = "\n"))
        }
        return true
    }

    private fun Bundle.cs(key: String): String? = getCharSequence(key)?.toString()

    /** extras 의 키 이름과 값 종류 (내용은 넣지 않는다) */
    private fun extrasShape(ex: Bundle): JSONObject {
        val o = JSONObject()
        for (key in ex.keySet().sorted()) {
            @Suppress("DEPRECATION")
            val v = ex.get(key)
            o.put(
                key,
                when (v) {
                    null -> "null"
                    is CharSequence -> "text(${v.length})"
                    is Array<*> -> "${v.javaClass.componentType?.simpleName}[${v.size}]"
                    else -> v.javaClass.simpleName
                },
            )
        }
        return o
    }

    /** MessagingStyle 메시지 목록 (보낸 사람 · 본문 · 시각) */
    @Suppress("DEPRECATION")
    private fun readMessages(ex: Bundle): List<JSONObject> {
        val arr = ex.getParcelableArray(Notification.EXTRA_MESSAGES) ?: return emptyList()
        return arr.mapNotNull { item ->
            val b = item as? Bundle ?: return@mapNotNull null
            val sender = b.getCharSequence("sender")?.toString()
                ?: if (Build.VERSION.SDK_INT >= 28) {
                    (b.getParcelable("sender_person") as? Person)?.name?.toString()
                } else {
                    null
                }
            JSONObject()
                .put("sender", sender ?: JSONObject.NULL)
                .put("text", b.getCharSequence("text")?.toString() ?: JSONObject.NULL)
                .put("time", b.getLong("time"))
        }
    }
}
