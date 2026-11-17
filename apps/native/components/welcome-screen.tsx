import { Ionicons } from "@expo/vector-icons";
import { DrawerActions } from "@react-navigation/native";
import { useNavigation, useRouter } from "expo-router";
import React, { useCallback, useState } from "react";
import {
  ActivityIndicator,
  FlatList,
  Image,
  Keyboard,
  Platform,
  Pressable,
  RefreshControl,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { GradientWave, LitLogo } from "@/components/lit-brand";
import { useAppAuth, UserSession } from "@/lib/auth-state";

export interface FeedPost {
  id: string;
  author: {
    name: string;
    username: string;
    avatar?: string | null;
    isVerified?: boolean;
  };
  timeAgo: string;
  content: string;
  image?: string | null;
  likes: number;
  isLiked?: boolean;
  comments: number;
  shares: number;
  tags?: string[];
}

interface WelcomeScreenProps {
  session: UserSession | null;
}

const INITIAL_POSTS: FeedPost[] = [
  {
    id: "post_1",
    author: {
      name: "Sophia Carter",
      username: "sophiac",
      avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&auto=format&fit=crop&q=80",
      isVerified: true,
    },
    timeAgo: "12m ago",
    content: "The sunset vibe at the rooftop session was completely unmatched today 🔥🌆 Who else was there? #litlife #goldenhour #cityvibes",
    image: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&auto=format&fit=crop&q=80",
    likes: 142,
    isLiked: false,
    comments: 28,
    shares: 14,
    tags: ["Music", "Vibes"],
  },
  {
    id: "post_2",
    author: {
      name: "Marcus Chen",
      username: "marcus_design",
      avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80",
      isVerified: true,
    },
    timeAgo: "45m ago",
    content: "Just finalized the new UI design tokens in Figma. Sleek dark mode with vibrant orange accents is definitely the move this year ⚡💻 #design #creative #uiux",
    image: "https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=800&auto=format&fit=crop&q=80",
    likes: 89,
    isLiked: true,
    comments: 12,
    shares: 6,
    tags: ["Design", "Tech"],
  },
  {
    id: "post_3",
    author: {
      name: "Elena Rostova",
      username: "elena_beats",
      avatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80",
      isVerified: false,
    },
    timeAgo: "2h ago",
    content: "Dropping a new ambient electronic mix tonight at 9 PM EST! Turn up the bass and get ready 🎧🎶 #electronic #nightshift #djset",
    image: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&auto=format&fit=crop&q=80",
    likes: 310,
    isLiked: false,
    comments: 45,
    shares: 33,
    tags: ["Music"],
  },
];

const SAMPLE_IMAGES = [
  "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=800&auto=format&fit=crop&q=80",
  "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80",
  "https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=800&auto=format&fit=crop&q=80",
  "https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&auto=format&fit=crop&q=80",
];

const STORIES = [
  { id: "my_story", name: "Your Story", isMe: true },
  { id: "story_1", name: "athik.design", avatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&auto=format&fit=crop&q=80", hasUnseen: true },
  { id: "story_2", name: "ui_ux frog", avatar: "https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=100&auto=format&fit=crop&q=80", hasUnseen: true },
  { id: "story_3", name: "sarah_m", avatar: "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=100&auto=format&fit=crop&q=80", hasUnseen: true },
  { id: "story_4", name: "david_k", avatar: "https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=100&auto=format&fit=crop&q=80", hasUnseen: false },
];

export function WelcomeScreen({ session }: WelcomeScreenProps) {
  const insets = useSafeAreaInsets();
  const navigation = useNavigation();
  const { signOut } = useAppAuth();

  const user = session?.user;
  const userInitials = user?.name
    ? user.name
        .split(" ")
        .map((n) => n[0])
        .join("")
        .substring(0, 2)
        .toUpperCase()
    : "L";

  // Feed State
  const [posts, setPosts] = useState<FeedPost[]>(INITIAL_POSTS);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);

  // Create Post Form State
  const [postText, setPostText] = useState("");
  const [attachedImage, setAttachedImage] = useState<string | null>(null);
  const [selectedTag, setSelectedTag] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Toggle Like Action
  const handleToggleLike = (postId: string) => {
    setPosts((prev) =>
      prev.map((post) => {
        if (post.id === postId) {
          const isLiked = !post.isLiked;
          return {
            ...post,
            isLiked,
            likes: isLiked ? post.likes + 1 : Math.max(0, post.likes - 1),
          };
        }
        return post;
      }),
    );
  };

  // Submit New Post
  const handleCreatePost = () => {
    if (!postText.trim() && !attachedImage) return;

    setIsSubmitting(true);
    setTimeout(() => {
      const newPost: FeedPost = {
        id: `user_post_${Date.now()}`,
        author: {
          name: user?.name || "Lit Member",
          username: user?.email ? user.email.split("@")[0] : "lituser",
          avatar: null,
          isVerified: true,
        },
        timeAgo: "Just now",
        content: postText.trim(),
        image: attachedImage,
        likes: 0,
        isLiked: false,
        comments: 0,
        shares: 0,
        tags: selectedTag ? [selectedTag] : undefined,
      };

      setPosts((prev) => [newPost, ...prev]);
      setPostText("");
      setAttachedImage(null);
      setSelectedTag(null);
      setIsSubmitting(false);
      Keyboard.dismiss();
    }, 350);
  };

  // Pull to Refresh
  const handleRefresh = useCallback(() => {
    setIsRefreshing(true);
    setTimeout(() => {
      setPosts((prev) => [
        {
          id: `fresh_${Date.now()}`,
          author: {
            name: "Alex Rivera",
            username: "alex_beats",
            avatar: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&auto=format&fit=crop&q=80",
            isVerified: true,
          },
          timeAgo: "Just now",
          content: "Fresh music drop right now on LIT stream! Plug in your headphones and vibe out 🎧⚡ #music #freshdrop",
          image: "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=800&auto=format&fit=crop&q=80",
          likes: 24,
          isLiked: false,
          comments: 5,
          shares: 2,
          tags: ["Music"],
        },
        ...prev,
      ]);
      setIsRefreshing(false);
    }, 700);
  }, []);

  // Infinite Scroll Load More
  const handleLoadMore = () => {
    if (isLoadingMore || !hasMore) return;

    setIsLoadingMore(true);
    setTimeout(() => {
      const morePosts: FeedPost[] = [
        {
          id: `loaded_${Date.now()}_1`,
          author: {
            name: "Zack Taylor",
            username: "zack_dev",
            avatar: "https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150&auto=format&fit=crop&q=80",
            isVerified: false,
          },
          timeAgo: "5h ago",
          content: "React Native 0.88 with Expo SDK 58 performance is astonishingly smooth. Testing animations at a steady 60fps! 🚀⚡",
          image: "https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&auto=format&fit=crop&q=80",
          likes: 54,
          isLiked: false,
          comments: 9,
          shares: 4,
          tags: ["Tech"],
        },
        {
          id: `loaded_${Date.now()}_2`,
          author: {
            name: "Maya Lin",
            username: "maya_art",
            avatar: "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150&auto=format&fit=crop&q=80",
            isVerified: true,
          },
          timeAgo: "8h ago",
          content: "Late night neon light studies. Color gradients evoke emotions like nothing else 🎨✨ #art #digitalart #lighting",
          image: "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=800&auto=format&fit=crop&q=80",
          likes: 198,
          isLiked: true,
          comments: 21,
          shares: 11,
          tags: ["Art", "Vibes"],
        },
      ];

      setPosts((prev) => [...prev, ...morePosts]);
      setIsLoadingMore(false);
    }, 900);
  };

  // Render Header Component: Top Bar + Stories + Create Post Form
  const renderListHeader = () => (
    <View style={styles.headerContainer}>
      {/* Top Bar */}
      <View style={[styles.topBar, { paddingTop: Math.max(insets.top, 14) }]}>
        <Pressable
          style={styles.iconButton}
          onPress={() => navigation.dispatch(DrawerActions.openDrawer())}
          accessibilityLabel="Open Menu"
          hitSlop={12}
        >
          <Ionicons name="menu-outline" size={24} color="#FFFFFF" />
        </Pressable>

        <LitLogo width={92} height={30} />

        <Pressable
          style={styles.profileButton}
          onPress={signOut}
          accessibilityLabel="Sign Out"
          hitSlop={12}
        >
          <View style={styles.headerAvatar}>
            <Text style={styles.headerAvatarText}>{userInitials}</Text>
          </View>
        </Pressable>
      </View>

      {/* Stories Carousel */}
      <View style={styles.storiesSection}>
        <FlatList
          data={STORIES}
          horizontal
          showsHorizontalScrollIndicator={false}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.storiesList}
          renderItem={({ item }) => {
            if (item.isMe) {
              return (
                <View style={styles.storyItem}>
                  <View style={styles.myStoryWrapper}>
                    <View style={styles.myStoryAvatar}>
                      <Text style={styles.myStoryAvatarText}>{userInitials}</Text>
                    </View>
                    <View style={styles.addStoryBadge}>
                      <Ionicons name="add" size={14} color="#FFFFFF" />
                    </View>
                  </View>
                  <Text style={styles.storyName} numberOfLines={1}>
                    Your Story
                  </Text>
                </View>
              );
            }
            return (
              <View style={styles.storyItem}>
                <View
                  style={[
                    styles.storyRing,
                    item.hasUnseen ? styles.storyRingActive : styles.storyRingSeen,
                  ]}
                >
                  <Image source={{ uri: item.avatar }} style={styles.storyAvatar} />
                </View>
                <Text style={styles.storyName} numberOfLines={1}>
                  {item.name}
                </Text>
              </View>
            );
          }}
        />
      </View>

      {/* Feed Post Form UI ("What's on your mind?") */}
      <View style={styles.feedFormCard}>
        <View style={styles.feedFormTopRow}>
          <View style={styles.formUserAvatar}>
            <Text style={styles.formUserAvatarText}>{userInitials}</Text>
          </View>
          <TextInput
            style={styles.feedInput}
            value={postText}
            onChangeText={setPostText}
            placeholder="What's vibing today? Share your scene..."
            placeholderTextColor="rgba(255, 255, 255, 0.4)"
            multiline
            maxLength={280}
          />
        </View>

        {/* Selected Image Preview */}
        {attachedImage && (
          <View style={styles.attachedImageWrapper}>
            <Image source={{ uri: attachedImage }} style={styles.attachedImage} />
            <Pressable
              style={styles.removeImageButton}
              onPress={() => setAttachedImage(null)}
              hitSlop={8}
            >
              <Ionicons name="close-circle" size={24} color="#FFFFFF" />
            </Pressable>
          </View>
        )}

        {/* Quick Tag Selectors */}
        <View style={styles.tagSelectorRow}>
          {["🔥 Lit", "⚡ Vibe", "🎵 Music", "💻 Tech", "🌆 City"].map((tag) => (
            <Pressable
              key={tag}
              style={[
                styles.tagPill,
                selectedTag === tag && styles.tagPillSelected,
              ]}
              onPress={() => setSelectedTag(selectedTag === tag ? null : tag)}
            >
              <Text
                style={[
                  styles.tagPillText,
                  selectedTag === tag && styles.tagPillTextSelected,
                ]}
              >
                {tag}
              </Text>
            </Pressable>
          ))}
        </View>

        {/* Form Bottom Action Toolbar */}
        <View style={styles.formActionsRow}>
          <View style={styles.mediaButtons}>
            <Pressable
              style={styles.actionIconBtn}
              onPress={() => {
                const randomImg =
                  SAMPLE_IMAGES[Math.floor(Math.random() * SAMPLE_IMAGES.length)];
                setAttachedImage(randomImg);
              }}
              hitSlop={8}
            >
              <Ionicons name="image-outline" size={20} color="#ED4113" />
            </Pressable>
            <Pressable
              style={styles.actionIconBtn}
              onPress={() => setSelectedTag("📍 Rooftop")}
              hitSlop={8}
            >
              <Ionicons name="location-outline" size={20} color="#FFA726" />
            </Pressable>
            <Pressable
              style={styles.actionIconBtn}
              onPress={() => setPostText((p) => (p ? `${p} #lit` : "#lit"))}
              hitSlop={8}
            >
              <Ionicons name="flame-outline" size={20} color="#FF5252" />
            </Pressable>
          </View>

          <Pressable
            style={({ pressed }) => [
              styles.postButton,
              (!postText.trim() && !attachedImage) && styles.postButtonDisabled,
              pressed && styles.postButtonPressed,
            ]}
            onPress={handleCreatePost}
            disabled={!postText.trim() && !attachedImage}
          >
            {isSubmitting ? (
              <ActivityIndicator color="#FFFFFF" size="small" />
            ) : (
              <>
                <Text style={styles.postButtonText}>Post</Text>
                <Ionicons name="paper-plane" size={14} color="#FFFFFF" style={{ marginLeft: 6 }} />
              </>
            )}
          </Pressable>
        </View>
      </View>
    </View>
  );

  // Render Post Card
  const renderPost = ({ item }: { item: FeedPost }) => {
    const postInitials = item.author.name
      .split(" ")
      .map((n) => n[0])
      .join("")
      .substring(0, 2)
      .toUpperCase();

    return (
      <View style={styles.postCard}>
        {/* Post Author Header */}
        <View style={styles.postHeader}>
          <View style={styles.authorRow}>
            {item.author.avatar ? (
              <Image source={{ uri: item.author.avatar }} style={styles.authorAvatar} />
            ) : (
              <View style={styles.authorAvatarFallback}>
                <Text style={styles.authorAvatarText}>{postInitials}</Text>
              </View>
            )}
            <View style={styles.authorMeta}>
              <View style={styles.authorNameRow}>
                <Text style={styles.authorName}>{item.author.name}</Text>
                {item.author.isVerified && (
                  <View style={styles.verifiedBadge}>
                    <Ionicons name="checkmark-sharp" size={10} color="#FFFFFF" />
                  </View>
                )}
              </View>
              <Text style={styles.authorUsername}>
                @{item.author.username} • {item.timeAgo}
              </Text>
            </View>
          </View>

          <Pressable hitSlop={12} style={styles.moreButton}>
            <Ionicons name="ellipsis-horizontal" size={18} color="rgba(255,255,255,0.6)" />
          </Pressable>
        </View>

        {/* Post Tags */}
        {item.tags && item.tags.length > 0 && (
          <View style={styles.postTagsRow}>
            {item.tags.map((tag) => (
              <View key={tag} style={styles.postTagBadge}>
                <Text style={styles.postTagBadgeText}>{tag}</Text>
              </View>
            ))}
          </View>
        )}

        {/* Post Caption / Content */}
        {item.content ? <Text style={styles.postContent}>{item.content}</Text> : null}

        {/* Post Media Image */}
        {item.image ? (
          <View style={styles.postImageWrapper}>
            <Image
              source={{ uri: item.image }}
              style={styles.postImage}
              resizeMode="cover"
            />
          </View>
        ) : null}

        {/* Post Action Bar (Like, Comment, Share, Save) */}
        <View style={styles.postActionsBar}>
          <View style={styles.postActionsLeft}>
            <Pressable
              style={styles.actionCountBtn}
              onPress={() => handleToggleLike(item.id)}
              hitSlop={8}
            >
              <Ionicons
                name={item.isLiked ? "flame" : "flame-outline"}
                size={22}
                color={item.isLiked ? "#ED4113" : "rgba(255, 255, 255, 0.7)"}
              />
              <Text
                style={[
                  styles.actionCountText,
                  item.isLiked && styles.actionCountTextLiked,
                ]}
              >
                {item.likes}
              </Text>
            </Pressable>

            <Pressable style={styles.actionCountBtn} hitSlop={8}>
              <Ionicons
                name="chatbubble-ellipses-outline"
                size={20}
                color="rgba(255, 255, 255, 0.7)"
              />
              <Text style={styles.actionCountText}>{item.comments}</Text>
            </Pressable>

            <Pressable style={styles.actionCountBtn} hitSlop={8}>
              <Ionicons
                name="repeat-outline"
                size={20}
                color="rgba(255, 255, 255, 0.7)"
              />
              <Text style={styles.actionCountText}>{item.shares}</Text>
            </Pressable>
          </View>

          <Pressable hitSlop={8}>
            <Ionicons name="bookmark-outline" size={20} color="rgba(255, 255, 255, 0.7)" />
          </Pressable>
        </View>
      </View>
    );
  };

  // Footer Loader for Infinite Scroll
  const renderListFooter = () => {
    if (!isLoadingMore) {
      return <View style={{ height: Math.max(insets.bottom + 24, 32) }} />;
    }
    return (
      <View style={styles.footerLoader}>
        <ActivityIndicator color="#ED4113" size="small" />
        <Text style={styles.footerLoaderText}>Loading more vibes...</Text>
      </View>
    );
  };

  return (
    <View style={styles.container}>
      {/* Background Glowing Gradient Header */}
      <GradientWave height={260} opacity={0.7} />

      <FlatList
        data={posts}
        keyExtractor={(item) => item.id}
        renderItem={renderPost}
        ListHeaderComponent={renderListHeader}
        ListFooterComponent={renderListFooter}
        refreshControl={
          <RefreshControl
            refreshing={isRefreshing}
            onRefresh={handleRefresh}
            tintColor="#ED4113"
            colors={["#ED4113"]}
          />
        }
        onEndReached={handleLoadMore}
        onEndReachedThreshold={0.4}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.listContent}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#07070E",
  },
  listContent: {
    paddingBottom: 20,
  },
  headerContainer: {
    paddingBottom: 8,
  },
  topBar: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 20,
    paddingBottom: 14,
    zIndex: 10,
  },
  iconButton: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: "rgba(255, 255, 255, 0.08)",
    alignItems: "center",
    justifyContent: "center",
  },
  profileButton: {
    padding: 2,
  },
  headerAvatar: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: "#ED4113",
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 1.5,
    borderColor: "#FFA726",
  },
  headerAvatarText: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "700",
  },

  // Stories Section
  storiesSection: {
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255, 255, 255, 0.06)",
  },
  storiesList: {
    paddingHorizontal: 16,
    gap: 14,
  },
  storyItem: {
    alignItems: "center",
    width: 68,
  },
  myStoryWrapper: {
    position: "relative",
    width: 58,
    height: 58,
    marginBottom: 6,
  },
  myStoryAvatar: {
    width: 58,
    height: 58,
    borderRadius: 29,
    backgroundColor: "rgba(255, 255, 255, 0.12)",
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 2,
    borderColor: "rgba(255, 255, 255, 0.2)",
  },
  myStoryAvatarText: {
    color: "#FFFFFF",
    fontSize: 18,
    fontWeight: "700",
  },
  addStoryBadge: {
    position: "absolute",
    bottom: -2,
    right: -2,
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: "#ED4113",
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 2,
    borderColor: "#07070E",
  },
  storyRing: {
    width: 58,
    height: 58,
    borderRadius: 29,
    padding: 2.5,
    marginBottom: 6,
  },
  storyRingActive: {
    borderWidth: 2.5,
    borderColor: "#ED4113",
  },
  storyRingSeen: {
    borderWidth: 1.5,
    borderColor: "rgba(255, 255, 255, 0.2)",
  },
  storyAvatar: {
    width: "100%",
    height: "100%",
    borderRadius: 26,
  },
  storyName: {
    color: "rgba(255, 255, 255, 0.75)",
    fontSize: 11,
    textAlign: "center",
  },

  // Feed Form UI
  feedFormCard: {
    backgroundColor: "rgba(255, 255, 255, 0.05)",
    borderWidth: 1,
    borderColor: "rgba(255, 255, 255, 0.09)",
    borderRadius: 20,
    padding: 14,
    marginHorizontal: 16,
    marginTop: 14,
  },
  feedFormTopRow: {
    flexDirection: "row",
    alignItems: "flex-start",
  },
  formUserAvatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: "#ED4113",
    alignItems: "center",
    justifyContent: "center",
    marginRight: 10,
    marginTop: 2,
  },
  formUserAvatarText: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "700",
  },
  feedInput: {
    flex: 1,
    minHeight: 46,
    color: "#FFFFFF",
    fontSize: 15,
    paddingTop: 6,
    paddingBottom: 6,
  },
  attachedImageWrapper: {
    position: "relative",
    marginTop: 10,
    borderRadius: 12,
    overflow: "hidden",
  },
  attachedImage: {
    width: "100%",
    height: 160,
    borderRadius: 12,
  },
  removeImageButton: {
    position: "absolute",
    top: 6,
    right: 6,
    backgroundColor: "rgba(0, 0, 0, 0.5)",
    borderRadius: 12,
  },
  tagSelectorRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 6,
    marginTop: 10,
    marginBottom: 6,
  },
  tagPill: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
    backgroundColor: "rgba(255, 255, 255, 0.06)",
    borderWidth: 1,
    borderColor: "rgba(255, 255, 255, 0.1)",
  },
  tagPillSelected: {
    backgroundColor: "rgba(237, 65, 19, 0.2)",
    borderColor: "#ED4113",
  },
  tagPillText: {
    color: "rgba(255, 255, 255, 0.65)",
    fontSize: 12,
  },
  tagPillTextSelected: {
    color: "#FF7043",
    fontWeight: "600",
  },
  formActionsRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginTop: 10,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: "rgba(255, 255, 255, 0.06)",
  },
  mediaButtons: {
    flexDirection: "row",
    gap: 12,
  },
  actionIconBtn: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: "rgba(255, 255, 255, 0.06)",
    alignItems: "center",
    justifyContent: "center",
  },
  postButton: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#ED4113",
    paddingHorizontal: 18,
    paddingVertical: 8,
    borderRadius: 88,
  },
  postButtonDisabled: {
    opacity: 0.45,
  },
  postButtonPressed: {
    opacity: 0.85,
    transform: [{ scale: 0.98 }],
  },
  postButtonText: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "700",
  },

  // Post Card
  postCard: {
    backgroundColor: "rgba(255, 255, 255, 0.04)",
    borderWidth: 1,
    borderColor: "rgba(255, 255, 255, 0.08)",
    borderRadius: 20,
    padding: 16,
    marginHorizontal: 16,
    marginTop: 14,
  },
  postHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 10,
  },
  authorRow: {
    flexDirection: "row",
    alignItems: "center",
  },
  authorAvatar: {
    width: 42,
    height: 42,
    borderRadius: 21,
    marginRight: 10,
  },
  authorAvatarFallback: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: "#ED4113",
    alignItems: "center",
    justifyContent: "center",
    marginRight: 10,
  },
  authorAvatarText: {
    color: "#FFFFFF",
    fontSize: 15,
    fontWeight: "700",
  },
  authorMeta: {
    justifyContent: "center",
  },
  authorNameRow: {
    flexDirection: "row",
    alignItems: "center",
  },
  authorName: {
    color: "#FFFFFF",
    fontSize: 15,
    fontWeight: "700",
    marginRight: 5,
  },
  verifiedBadge: {
    width: 15,
    height: 15,
    borderRadius: 7.5,
    backgroundColor: "#ED4113",
    alignItems: "center",
    justifyContent: "center",
  },
  authorUsername: {
    color: "rgba(255, 255, 255, 0.5)",
    fontSize: 12,
    marginTop: 1,
  },
  moreButton: {
    padding: 4,
  },
  postTagsRow: {
    flexDirection: "row",
    gap: 6,
    marginBottom: 8,
  },
  postTagBadge: {
    backgroundColor: "rgba(237, 65, 19, 0.15)",
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 8,
  },
  postTagBadgeText: {
    color: "#FF7043",
    fontSize: 11,
    fontWeight: "600",
  },
  postContent: {
    color: "rgba(255, 255, 255, 0.9)",
    fontSize: 14,
    lineHeight: 21,
    marginBottom: 12,
  },
  postImageWrapper: {
    borderRadius: 16,
    overflow: "hidden",
    marginBottom: 12,
  },
  postImage: {
    width: "100%",
    height: 220,
    backgroundColor: "rgba(255, 255, 255, 0.05)",
  },
  postActionsBar: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingTop: 6,
  },
  postActionsLeft: {
    flexDirection: "row",
    alignItems: "center",
    gap: 18,
  },
  actionCountBtn: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
  },
  actionCountText: {
    color: "rgba(255, 255, 255, 0.7)",
    fontSize: 13,
    fontWeight: "500",
  },
  actionCountTextLiked: {
    color: "#ED4113",
    fontWeight: "700",
  },

  // Footer Loader
  footerLoader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 20,
    gap: 8,
  },
  footerLoaderText: {
    color: "rgba(255, 255, 255, 0.6)",
    fontSize: 13,
  },
});
